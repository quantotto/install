from typing import Dict
import click
import yaml
import pprint
import subprocess
import base64
import time
from dotted_dict import DottedDict
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
from quantotto.mgmt_py_sdk.swagger_client import (
    Configuration,
    ApiClient,
    SiteApi,
    ClassifierApi,
    ScenarioApi,
    Site,
    Classifier,
    ScenarioFlow,
    ScenarioGroup,
    Graph,
    Node,
    Connection,
)

STANDALONE = "standalone"
K8S = "k8s"
TARGETS = (STANDALONE, K8S)
SUPER_TXT = "super.txt"

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
    click.echo(f"Client secret: {client_secret}")
    return request_access_token(
        hydra_public_url,
        client_id=client_id,
        client_secret=client_secret,
        audience="management_api"
    )

def install_standalone(ctx, config: DottedDict):
    click.echo(f"*** Installing standalone ***")
    product_config = config.product
    srv_password = "quantott0"
    ctx.invoke(
        standalone_product_config,
        quantotto_version=product_config.quantotto_version,
        server_fqdn=product_config.server_fqdn,
        server_ip=product_config.server_ip,
        management_port=product_config.management_port,
        frames_port=product_config.frames_port,
        internal_host_subnet=product_config.internal_host_subnet,
        docker_subnet=product_config.docker_subnet,
        retention_days=product_config.retention_days,
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

    click.echo(f"*** Running deploy command ***")
    ctx.invoke(standalone_product_deploy)

    click.echo("*** creating customer ***")
    customer_config = config.customers[0]
    with open(SUPER_TXT, "r") as f:
        superadmin_secret = f.read().lstrip().rstrip()
    ctx.invoke(
        standalone_customer_create,
        customer_id=customer_config.id,
        customer_name=customer_config.name,
        admin_email=customer_config.admin_email,
        admin_login=customer_config.admin_login,
        admin_first_name=customer_config.admin_fname,
        admin_middle_name=customer_config.admin_mname,
        admin_last_name=customer_config.admin_lname,
        admin_password=customer_config.admin_password,
        superadmin_secret=superadmin_secret
    )

def install_k8s(ctx, config: DottedDict):
    click.echo(f"Installing k8s")
    product_config = config.product
    k8s_config = config.k8s
    srv_password = product_config.get("server_password", "quantott0")
    ctx.invoke(
        k8s_server_config,
        quantotto_version=product_config.quantotto_version,
        portal_fqdn=product_config.server_fqdn,
        cluster_domain=k8s_config.cluster_domain,
        server_namespace=k8s_config.namespace,
        customer_namespace_prefix=k8s_config.namespace + "-",
        repo="quantotto",
        repo_user="quantotto",
        repo_password=k8s_config.repo_password,
        storage_class=k8s_config.storage_class,
        retention_days=product_config.retention_days,
        qdb_password=srv_password,
        mongodb_password=srv_password,
        ldap_admin_password=srv_password,
        encrypt_secrets=k8s_config.encrypt_secrets
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
        "-n", k8s_config.namespace,
        "--template={{.data.HYDRA_SUPER_ADMIN_SECRET}}"
    ]
    p = subprocess.Popen(
        args=kubectl_args,
        stdout=subprocess.PIPE,
        stdin=subprocess.PIPE,
        stderr=subprocess.PIPE
    )
    stdout_data, _ = p.communicate(b"")
    if p.returncode != 0:
        raise Exception(
            f"kubectl failed {kubectl_args}"
        )
    super_admin_secret = base64.b64decode(stdout_data).decode()
    with open(SUPER_TXT, "w") as f:
        f.write(super_admin_secret)
    click.echo("Server deployed")
    for customer_config in config.customers:
        customer_id = customer_config.id
        click.echo(f"Deploying services for customer {customer_id}")
        ctx.invoke(
            k8s_customer_config,
            customer_id=customer_id,
            customer_name=customer_config.name,
            admin_email=customer_config.admin_email,
            admin_login=customer_config.admin_login,
            admin_first_name=customer_config.admin_fname,
            admin_middle_name=customer_config.admin_mname,
            admin_last_name=customer_config.admin_lname,
            admin_password=customer_config.admin_password,
            super_admin_secret=super_admin_secret
        )
        helmfile_args = [
            "helmfile", "-f",
            f"/opt/quantotto/install/helmfile/{customer_id}_customer_helmfile.yaml", "sync"
        ]
        p = subprocess.run(helmfile_args)
        if p.returncode:
            raise Exception(
                f"helmfile failed to deploy customer {customer_id}"
            )
        click.echo("helmfile done for customer")


def prep_k8s_customer_env(customer_id: str, k8s_config: DottedDict):
    cfg_args = [
        "/opt/quantotto/agent_cfg.sh",
        customer_id,
        k8s_config.namespace
    ]
    p = subprocess.run(cfg_args)
    if p.returncode:
        raise Exception(f"failed to set environment for customer {customer_id}")

def create_objects(customer: DottedDict, product_config: DottedDict):
    client_id = getvar("CUSTOMER_ID")
    client_secret = getvar("HYDRA_CUSTOMER_CLIENT_SECRET")
    portal_fqdn = product_config.server_fqdn
    mgmt_port = product_config.management_port
    token = get_api_token(
        portal_fqdn,
        mgmt_port,
        client_id,
        client_secret
    ).get("access_token")
    click.echo(f"API token: {token}")
    config = Configuration()
    config.access_token = token
    config.host = f"https://{portal_fqdn}:{mgmt_port}/api/v1"
    api_client = ApiClient(config)
    postinstall_config = customer.postinstall
    if postinstall_config.site:
        site_name = postinstall_config.site
        click.echo(f"Creating {site_name} site... ", nl=False)
        try:
            site_api = SiteApi(api_client)
            my_site = Site(site_name=site_name)
            site_api.add_site(my_site)
            click.echo("Done")
        except Exception as e:
            click.echo("Error")
            click.echo(f"Exception adding site {site_name}: {str(e)}")


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
        config = DottedDict(yaml.load(config_buf, Loader=yaml.SafeLoader))
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
    k8s_config = {}
    with config_file.open("rb") as f:
        config_buf = f.read()
        config = DottedDict(yaml.load(config_buf, Loader=yaml.SafeLoader))
        product_config = config.product
        if target == K8S:
            k8s_config = config.k8s
    if target == STANDALONE:
        customers = config.customers[0:1]
    else:
        customers = config.customers
    for c in customers:
        if target == K8S:
            prep_k8s_customer_env(c.id, k8s_config)
        create_objects(
            c, product_config
        )


if __name__ == '__main__':
    entrypoint()
