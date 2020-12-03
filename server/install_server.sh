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
    libpq-dev postgresql-client

echo -n "Creating application folder (${APP_FOLDER})... "
sudo mkdir -p ${APP_FOLDER}
sudo mkdir -p ${APP_FOLDER}/certs
echo "Done"
echo -n "Setting permissions... "
sudo chown -R ${ACCOUNT}:${ACCOUNT} ${APP_FOLDER}
sudo chmod -R 775 ${APP_FOLDER}
echo "Done"

echo -n "Creating Python3 virtual environment under ${APP_FOLDER}/.venv... "
python3 -m venv ${APP_FOLDER}/.venv
echo "Done"

source ${APP_FOLDER}/.venv/bin/activate
pip install -U pip
echo -n "Activated virtual environment"

echo "Installing Quantotto Server CLI package"
pip install -U --index-url http://devops.quantotto.io:16280 --trusted-host devops.quantotto.io quantotto.cli_server

echo "Cloning rpi image builder repo"
git clone git@github.com:quantotto/rpi ${APP_FOLDER}/rpi
echo "Setting up environment variables"

sudo tee -a /etc/profile.d/quantotto.sh >/dev/null <<EOF
export QUANTOTTO_HOME=${APP_FOLDER}
export VIRTUAL_ENV="${APP_FOLDER}/.venv"
export PATH="${APP_FOLDER}/.venv/bin:$PATH"
export QUANTOTTO_CA_CERT="${APP_FOLDER}/certs/fullchain.pem"
EOF

sudo chmod ugo+x /etc/profile.d/quantotto.sh
sudo chown -R ${ACCOUNT}:${ACCOUNT} ${APP_FOLDER}
sudo chmod -R 775 ${APP_FOLDER}

echo "All done!"
