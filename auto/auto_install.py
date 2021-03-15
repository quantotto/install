from typing import Dict
import click
import yaml
import pprint
import sys
import subprocess
import base64
from pathlib import Path

from quantotto.cli_server.entrypoint import entrypoint as standalone_entrypoint
from quantotto.cli_k8s.entrypoint import entrypoint as k8s_entrypoint

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


def install_standalone(config: Dict):
    print(f"Installing standalone")
    product_config = config.get("product")
    srv_password = "quantott0"
    sys.argv = [
        sys.argv[0],
        "product",
        "config",
        "--quantotto-version", product_config.get("quantotto_version"),
        "--server-fqdn", product_config.get("server_fqdn"),
        "--server-ip", product_config.get("server_ip"),
        "--management-port", product_config.get("management_port"),
        "--frames-port", product_config.get("frames_port"),
        "--internal-host-subnet", product_config.get("internal_host_subnet"),
        "--docker-subnet", product_config.get("docker_subnet"),
        "--retention-days", product_config.get("retention_days"),
        "--data-volume", product_config.get("data_volume", "/opt/quantotto/data"),
        "--qdb-host", "qdb",
        "--qdb-user", "quantotto",
        "--qdb-password", srv_password,
        "--influxdb-host", "influxdb",
        "--influxdb-user", "quantotto",
        "--influxdb-password", srv_password,
        "--mongodb-host", "mongodb",
        "--mongodb-user", "quantotto",
        "--mongodb-password", srv_password,
        "--ldap-uri", "ldap://openldap:389",
        "--ldap-admin-password", srv_password
    ]
    standalone_entrypoint()
    sys.argv[
        sys.argv[0],
        "product",
        "deploy"
    ]
    standalone_entrypoint()
    customer_config = config.get("customers")[0]
    with open("super.txt", "r") as f:
        superadmin_secret = f.read().lstrip().rstrip()
    sys.argv[
        sys.argv[0],
        "customer",
        "create",
        "--customer-id", customer_config.get("id"),
        "--customer-name", customer_config.get("name"),
        "--admin-email", customer_config.get("admin_email"),
        "--admin-login", customer_config.get("admin_login"),
        "--admin-first-name", customer_config.get("admin_fname"),
        "--admin-middle-name", customer_config.get("admin_mname"),
        "--admin-last-name", customer_config.get("admin_lname"),
        "--admin-password", customer_config.get("admin_password"),
        "--superadmin-secret", superadmin_secret
    ]
    standalone_entrypoint()

def install_k8s(config: Dict):
    print(f"Installing k8s")
    product_config = config.get("product")
    k8s_config = config.get("k8s")
    srv_password = "quantott0"
    sys.argv = [
        sys.argv[0],
        "server",
        "config",
        "--quantotto-version", product_config.get("quantotto_version"),
        "--server-fqdn", product_config.get("server_fqdn"),
        "--cluster-domain", k8s_config.get("cluster_domain"),
        "--server=namespace", k8s_config.get("namespace"),
        "--customer-namespace-prefix", k8s_config.get("namespace") + "-",
        "--repo", "quantotto",
        "--repo-user", "quantotto",
        "--repo-password", k8s_config.get("repo_password", ""),
        "--storage-class", k8s_config.get("storage_class"),
        "--retention-days", product_config.get("retention_days"),
        "--qdb-password", srv_password,
        "--mongodb-password", srv_password,
        "--ldap-admin-password", srv_password,
        "--encrypt-secrets", k8s_config.get("encrypt_secrets")
    ]
    k8s_entrypoint()
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
        sys.argv = [
            sys.argv[0],
            "customer",
            "config",
            "--customer-id", customer_id,
            "--customer-name", customer_config.get("name"),
            "--admin-email", customer_config.get("admin_email"),
            "--admin-login", customer_config.get("admin_login"),
            "--admin-first-name", customer_config.get("admin_fname"),
            "--admin-middle-name", customer_config.get("admin_mname"),
            "--admin-last-name", customer_config.get("admin_lname"),
            "--admin-password", customer_config.get("admin_password"),
            "--super-admin-secret", super_admin_secret
        ]
        k8s_entrypoint()
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
def install(target: str, config_file: Path):
    with config_file.open("rb") as f:
        config_buf = f.read()
        config = yaml.load(config_buf, Loader=yaml.SafeLoader)
    pprint.pprint(config)
    if target == "standalone":
        install_standalone(config)
    elif target == "k8s":
        install_k8s(config)

if __name__ == '__main__':
    entrypoint()