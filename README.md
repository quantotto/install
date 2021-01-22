# Quantotto Installers

Install / Uninstall scripts for Standalone Deployment of Quantotto applications (server and agent/s).

# Standalone Installation

https://www.quantotto.io/docs/deployment_guide/standalone_deployment.html

# Kubernetes Installation

Prerequisites:
- Python 3.6+
- kubectl (configured to connect to Kubernetes Cluster)
- helm
- helmfile

For secrets encryption:
- helm secrets plugin (`helm plugin install https://github.com/jkroepke/helm-secrets --version v3.4.0`)
- sops
- gpg

