#!/bin/bash

set -e

trap onerror ERR

function onerror() {
    echo "Error installing Quantotto Server CLI"
}

./precheck.sh

ARCHIVES=libarchive-tools
ubuntu_release=`lsb_release -a 2>/dev/null | grep "Release:" | awk '{ print $2; }'`
if [[ ${ubuntu_release} < 18.04 ]]; then
    ARCHIVES=bsdtar
fi

ACCOUNT=quantotto
APP_FOLDER=/opt/quantotto
USER_VERSION="3.3"
if [ ! -z $1 ]; then
    USER_VERSION=$1

VERSION="~=${USER_VERSION}.0"

echo "Updating system"
sudo apt-get -yy update && sudo apt-get -yy upgrade

echo "Installing pre-requisites"
sudo apt-get -yy install \
    coreutils quilt parted \
    qemu-user-static debootstrap \
    zerofree zip dosfstools \
    ${ARCHIVES} libcap2-bin grep \
    rsync xz-utils file git curl bc \
    python3-venv python3-dev \
    libsasl2-dev libldap2-dev libssl-dev \
    docker-compose build-essential \
    libpq-dev postgresql-client nano

echo -n "Creating application folder (${APP_FOLDER})... "
sudo mkdir -p ${APP_FOLDER}
sudo mkdir -p ${APP_FOLDER}/certs
echo "Done"
echo -n "Setting permissions... "
sudo chown -R ${ACCOUNT}:${ACCOUNT} ${APP_FOLDER}
sudo chmod -R 775 ${APP_FOLDER}
echo "Done"

echo -n "Creating Python3 virtual environment under ${APP_FOLDER}/.venv... "
if [ -e ${APP_FOLDER}/.venv ]; then
    rm -rf ${APP_FOLDER}/.venv
fi
python3 -m venv ${APP_FOLDER}/.venv
echo "Done"

source ${APP_FOLDER}/.venv/bin/activate
pip install -U pip
echo "Activated virtual environment"

echo "Installing Quantotto Server CLI package"
pip install -U --index-url http://devops.quantotto.io:16280 --trusted-host devops.quantotto.io quantotto.cli_server${VERSION} quantotto.cli_k8s${VERSION}

echo "Downloading rpi image builder"
PI_GEN_RELEASE=2020-12-02-raspbian-buster
sudo curl https://codeload.github.com/RPi-Distro/pi-gen/tar.gz/${PI_GEN_RELEASE} -o ${APP_FOLDER}/pi-gen.tar.gz
sudo tar xzf ${APP_FOLDER}/pi-gen.tar.gz -C ${APP_FOLDER}
sudo mv ${APP_FOLDER}/pi-gen-${PI_GEN_RELEASE} ${APP_FOLDER}/pi-gen
sudo rm -rf ${APP_FOLDER}/pi-gen.tar.gz
sudo tee -a ${APP_FOLDER}/pi-gen/config >/dev/null <<EOF
IMG_NAME="quantotto"
DEPLOY_DIR="\$BASE_DIR/base_image"
DEPLOY_ZIP=0
LOCALE_DEFAULT="en_US.UTF-8"
KEYBOARD_KEYMAP="us"
KEYBOARD_LAYOUT="English (US)"
TIMEZONE_DEFAULT="America/Los_Angeles"
ENABLE_SSH=1
EOF
sudo touch ${APP_FOLDER}/pi-gen/stage3/SKIP ${APP_FOLDER}/pi-gen/stage4/SKIP ${APP_FOLDER}/pi-gen/stage5/SKIP
sudo touch ${APP_FOLDER}/pi-gen/stage4/SKIP_IMAGES ${APP_FOLDER}/pi-gen/stage5/SKIP_IMAGES

echo "Setting up environment variables"
sudo tee -a /etc/profile.d/quantotto.sh >/dev/null <<EOF
export QUANTOTTO_HOME=${APP_FOLDER}
export VIRTUAL_ENV="${APP_FOLDER}/.venv"
export PATH="${APP_FOLDER}/.venv/bin:$PATH"
export QUANTOTTO_CA_CERT="${APP_FOLDER}/certs/fullchain.pem"
EOF

sudo tee -a ${APP_FOLDER}/agent_cfg.sh >/dev/null <<'EOF'
#!/bin/bash

if [ -z $1 ] || [ -z $2 ]; then
    echo "Usage: source $QUANTOTTO_HOME/agent_cfg.sh <customer ID> <server namespace>"
else
    SERVER_FQDN=$(kubectl get configmap/api-common -n $2 --template={{.data.PORTAL_FQDN}})
    SERVER_IP=$(kubectl get service nginx -n $2 | grep nginx | awk '{ printf($4); }')
    echo "CUSTOMER_ID=$1" > $QUANTOTTO_HOME/.env
    echo "FRAMES_PORT=15000" >> $QUANTOTTO_HOME/.env
    echo "HYDRA_CUSTOMER_CLIENT_SECRET=$(kubectl get secret/customer-secret-$1 -n $2 --template={{.data.HYDRA_CLIENT_SECRET}} | base64 --decode)" >> $QUANTOTTO_HOME/.env
    echo "SERVER_FQDN=${SERVER_FQDN}" >> $QUANTOTTO_HOME/.env
    echo "SERVER_IP=${SERVER_IP}" >> $QUANTOTTO_HOME/.env

    mkdir -p $QUANTOTTO_HOME/certs
    kubectl get secret/certs -n quantotto -o 'go-template={{index .data "tls.crt"}}' | base64 --decode > $QUANTOTTO_HOME/certs/quantotto.crt
    QUANTOTTO_CA_CERT=$QUANTOTTO_HOME/certs/quantotto.crt
    sed "/${SERVER_FQDN}/d" /etc/hosts | sed "1i${SERVER_IP}\t${SERVER_FQDN}" | sudo tee /etc/hosts >/dev/null
fi
EOF


sudo mkdir -p ${APP_FOLDER}/install/helmfile
sudo cp -R ../helmfile/* ${APP_FOLDER}/install/helmfile

sudo chmod ugo+x /etc/profile.d/quantotto.sh
sudo chown -R ${ACCOUNT}:${ACCOUNT} ${APP_FOLDER}
sudo chmod -R 775 ${APP_FOLDER}

echo "All done!"
echo ""
echo "***********************************************************************"
echo "Quantotto application was installed."
echo ""
echo "Please logout / login for environment settings to take effect."
echo "***********************************************************************"
echo ""
