from typing import Dict
import click
import yaml
import pprint
import sys
import subprocess
import base64
from pathlib import Path

from quantotto.cli_server.product import (
    product_config as standalone_product_config,
    product_deploy as standalone_product_deploy
)
from quantotto.cli_server.customer import customer_create as standalone_customer_create
from quantotto.cli_k8s.server import server_config as k8s_server_config
from quantotto.cli_k8s.customer import customer_config as k8s_customer_config

from quantotto.cli_server.env import getvar
from quantotto.auth.token_authenticator import request_access_token

TARGETS = ("standalone", "k8s")

def validate_target(ctx, param, value):
    if not value:
        raise click.BadParameter(
            "No target supplied."
        )
    if value not in TARGETS:
        raise click.BadParameter(
            f"Invalid target. Must be one of {TARGETS}."
        )
    return value

def validate_config(ctx, param, value):
    config_path = Path(value)
    if (not config_path.exists() or not config_path.is_file()):
        raise click.BadParameter(
            f"Config file does NOT exist."
        )
    return config_path

def get_api_token(
    server_fqdn: str,
    mgmt_port: int,
    client_id: str,
    client_secret: str
) -> str:
    hydra_public_url = f"https://{server_fqdn}:{mgmt_port}/hydra-public"
    print(f"Client secret: {client_secret}")
    return request_access_token(
        hydra_public_url,
        client_id=client_id,
        client_secret=client_secret,
        audience="management_api"
    )

def install_standalone(ctx, config: Dict):
    print(f"*** Installing standalone ***")
    product_config = config.get("product")
    srv_password = "quantott0"
    ctx.invoke(
        standalone_product_config,
        quantotto_version=product_config.get("quantotto_version"),
        server_fqdn=product_config.get("server_fqdn"),
        server_ip=product_config.get("server_ip"),
        management_port=product_config.get("management_port"),
        frames_port=product_config.get("frames_port"),
        internal_host_subnet=product_config.get("internal_host_subnet"),
        docker_subnet=product_config.get("docker_subnet"),
        retention_days=product_config.get("retention_days"),
        data_volume=product_config.get("data_volume", "/opt/quantotto/data"),
        qdb_host="qdb",
        qdb_user="quantotto",
        qdb_password=srv_password,
        influxdb_host="influxdb",
        influxdb_user="quantotto",
        influxdb_password=srv_password,
        mongodb_host="mongodb",
        mongodb_user="quantotto",
        mongodb_password=srv_password,
        ldap_uri="ldap://openldap:389",
        ldap_admin_password=srv_password
    )

    print(f"*** Running deploy command ***")
    ctx.invoke(standalone_product_deploy)

    print("*** creating customer ***")
    customer_config = config.get("customers")[0]
    with open("super.txt", "r") as f:
        superadmin_secret = f.read().lstrip().rstrip()
    ctx.invoke(
        standalone_customer_create,
        customer_id=customer_config.get("id"),
        customer_name=customer_config.get("name"),
        admin_email=customer_config.get("admin_email"),
        admin_login=customer_config.get("admin_login"),
        admin_first_name=customer_config.get("admin_fname"),
        admin_middle_name=customer_config.get("admin_mname"),
        admin_last_name=customer_config.get("admin_lname"),
        admin_password=customer_config.get("admin_password"),
        superadmin_secret=superadmin_secret
    )

def install_k8s(ctx, config: Dict):
    print(f"Installing k8s")
    product_config = config.get("product")
    k8s_config = config.get("k8s")
    srv_password = product_config.get("server_password", "quantott0")
    ctx.invoke(
        k8s_server_config,
        quantotto_version=product_config.get("quantotto_version"),
        server_fqdn=product_config.get("server_fqdn"),
        cluster_domain=k8s_config.get("cluster_domain"),
        server_namespace=k8s_config.get("namespace"),
        customer_namespace_prefix=k8s_config.get("namespace") + "-",
        repo="quantotto",
        repo_user="quantotto",
        repo_password=k8s_config.get("repo_password", ""),
        storage_class=k8s_config.get("storage_class"),
        retention_days=product_config.get("retention_days"),
        qdb_password=srv_password,
        mongodb_password=srv_password,
        ldap_admin_password=srv_password,
        encrypt_secrets=k8s_config.get("encrypt_secrets")
    )
    helmfile_args = [
        "helmfile", "-f",
        "/opt/quantotto/install/helmfile/server_helmfile.yaml", "sync"
    ]
    p = subprocess.run(helmfile_args)
    if p.returncode:
        raise Exception(
            f"helmfile failed to deploy server"
        )
    kubectl_args = [
        "kubectl", "get",
        "secrets/config-super-admin",
        "-n", k8s_config.get("namespace"),
        "--template={{.data.HYDRA_SUPER_ADMIN_SECRET}}"
    ]
    p = subprocess.Popen(
        args=kubectl_args,
        stdout=subprocess.PIPE,
        stdin=subprocess.PIPE,
        stderr=subprocess.PIPE
    )
    stdout_data, _ = p.communicate(b"")
    super_admin_secret = base64.b64decode(stdout_data)
    with open("super.txt", "w") as f:
        f.write(super_admin_secret)
    for customer_config in config.get("customers"):
        customer_id = customer_config.get("id")
        print(f"Deploying services for customer {customer_id}")
        ctx.invoke(
            k8s_customer_config,
            customer_id=customer_id,
            customer_name=customer_config.get("name"),
            admin_email=customer_config.get("admin_email"),
            admin_login=customer_config.get("admin_login"),
            admin_first_name=customer_config.get("admin_fname"),
            admin_middle_name=customer_config.get("admin_mname"),
            admin_last_name=customer_config.get("admin_lname"),
            admin_password=customer_config.get("admin_password"),
            super_admin_secret=super_admin_secret
        )
        helmfile_args = [
            "helmfile", "-f",
            f"/opt/quantotto/install/helmfile/{customer_id}_customer_helmfile.yaml", "sync"
        ]
        p = subprocess.run(helmfile_args)
        if p.returncode:
            print(
                f"helmfile failed to deploy customer {customer_id}"
            )


@click.group()
def entrypoint():
    """ Quantotto automatic installation
    """

@entrypoint.command("install")
@click.option("--target",
              type=str, required=True, callback=validate_target,
              help=f"deployment target {TARGETS}")
@click.option("--config-file",
              type=str, required=True, callback=validate_config,
              help=f"deployment config file path")
@click.pass_context
def install(ctx, target: str, config_file: Path):
    """Installs Quantotto product
    """
    with config_file.open("rb") as f:
        config_buf = f.read()
        config = yaml.load(config_buf, Loader=yaml.SafeLoader)
    pprint.pprint(config)
    if target == "standalone":
        install_standalone(ctx, config)
    elif target == "k8s":
        install_k8s(ctx, config)


@entrypoint.command("postinstall")
@click.option("--target",
              type=str, required=True, callback=validate_target,
              help=f"deployment target {TARGETS}")
@click.option("--config-file",
              type=str, required=True, callback=validate_config,
              help=f"deployment config file path")
@click.pass_context
def postinstall(ctx, target: str, config_file: Path):
    """Configures Quantotto product post installation
    leveraging Management API
    """
    if target == "k8s":
        print("k8s postinstall coming soon")
        return
    with config_file.open("rb") as f:
        config_buf = f.read()
        config = yaml.load(config_buf, Loader=yaml.SafeLoader)
        product_config = config.get("product")
    client_id = getvar("CUSTOMER_ID")
    client_secret = getvar("HYDRA_CUSTOMER_CLIENT_SECRET")
    token = get_api_token(
        product_config.get("server_fqdn"),
        product_config.get("management_port"),
        client_id,
        client_secret
    ).get("access_token")
    click.echo(f"API token: {token}")


if __name__ == '__main__':
    entrypoint()
