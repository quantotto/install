#!/bin/bash

set -e

trap onerror ERR

function onerror() {
    echo "Error installing Quantotto Agent CLI"
}

./precheck.sh


ACCOUNT=quantotto
APP_FOLDER=/opt/quantotto
QUANTOTTO_HOME=${APP_FOLDER}

echo "Updating system"
sudo apt-get -yy update && sudo apt-get -yy upgrade

sudo apt-get -yy install \
    curl file gdb gdbserver ccache \
    gcovr cppcheck unzip nano zip pkg-config \
    build-essential python3-dev python3-venv \
    libssl-dev libxml2-dev libxslt1-dev libffi-dev \
    zlib1g-dev libglib2.0-dev libsm6 \
    libxrender1 libxext6 libportaudio2 \
    libsndfile1 libbluetooth-dev libcap2-bin \
    bluetooth bluez bluez-tools libzbar0 \
    tcpdump iputils-ping net-tools nano \
    libass-dev libfreetype6-dev libjpeg-dev \
    libtheora-dev libtool libvorbis-dev \
    libx264-dev libfdk-aac-dev libxvidcore-dev \
    checkinstall libfaac-dev libgpac-dev \
    libmp3lame-dev libopencore-amrnb-dev \
    libopencore-amrwb-dev librtmp-dev \
    texi2html libasound-dev \
    libvpx-dev pkg-config wget yasm

echo -n "Creating application folder (${APP_FOLDER})... "
sudo mkdir -p ${APP_FOLDER}
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

echo "Installing Quantotto Agent CLI package"
pip install -U quantotto.cli-agent --index-url http://devops.quantotto.io:16280 --trusted-host devops.quantotto.io
ZEEP_FOLDER=$( dirname $( python -c "import zeep; print(zeep.__file__)" ) )
cp simple.py ${ZEEP_FOLDER}/xsd/types/simple.py

cp qtoagent_service.sh ${QUANTOTTO_HOME}/
#cp customer_config.yaml ${QUANTOTTO_HOME}/
#cp quantotto.crt ${QUANTOTTO_HOME}/

echo "Setting permissions"
sudo chown -R ${ACCOUNT}:${ACCOUNT} ${QUANTOTTO_HOME}
sudo chmod ugo+x ${QUANTOTTO_HOME}/qtoagent_service.sh

echo "Copying environment profile"
sudo cp quantotto.sh /etc/profile.d/
sudo chmod ugo+x /etc/profile.d/quantotto.sh

# install service
echo "Installing qtoagent service"
sudo cp qtoagent.service /lib/systemd/system/
sudo systemctl enable qtoagent.service
sudo systemctl start qtoagent.service


echo ""
echo "***********************************************************************"
echo "Quantotto Agent applications installed successfully."
echo ""
echo "Please logout / login for environment variables to take effect"
echo "***********************************************************************"
echo ""