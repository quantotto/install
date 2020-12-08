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
python3 -m venv ${APP_FOLDER}/.venv
echo "Done"

source ${APP_FOLDER}/.venv/bin/activate
pip install -U pip
echo -n "Activated virtual environment"

echo "Installing Quantotto Server CLI package"
pip install -U --index-url http://devops.quantotto.io:16280 --trusted-host devops.quantotto.io quantotto.cli_server

echo "Cloning rpi image builder repo"
git clone https://github.com/RPi-Distro/pi-gen ${APP_FOLDER}/pi-gen
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
touch ${APP_FOLDER}/pi-gen/stage3/SKIP ${APP_FOLDER}/pi-gen/stage4/SKIP ${APP_FOLDER}/pi-gen/stage5/SKIP
touch ${APP_FOLDER}/pi-gen/stage4/SKIP_IMAGES ${APP_FOLDER}/pi-gen/stage5/SKIP_IMAGES

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
echo ""
echo "***********************************************************************"
echo "Quantotto application was uninstalled."
echo ""
echo "Please logout / login for environment settings to take effect."
echo "***********************************************************************"
echo ""
