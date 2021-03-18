#!/bin/bash

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

PUSHD_FLAG=0

function onerror() {
    echo -e "${RED}Error auto-installing quantotto $?${NC}"
    if [ "${PUSHD_FLAG}" == "1" ]; then
        popd
    fi
    exit 1
}

trap onerror ERR

if [ -z $1 ]; then
    echo "No target specified"
    echo "Usage $0 <target: k8s or standalone> <config name>"
    exit 1
fi

if [ -z $2 ]; then
    echo "No config name specified"
    echo "Usage $0 <target: k8s or standalone> <config name>"
    exit 1
fi

if [ ! -e /opt/quantotto/.venv ] || [ ! -e /etc/profile.d/quantotto.sh ]; then
    pushd server/
    PUSHD_FLAG=1
    ./install_server.sh
    popd
    PUSHD_FLAG=0
fi
source /etc/profile.d/quantotto.sh
if [ "$1" == "k8s" ]; then
    QUANTOTTO_CA_CERT=/opt/quantotto/certs/quantotto.crt
fi

pushd auto/
PUSHD_FLAG=1
python auto_install.py install --target $1 --config-file $2.yaml
REQUESTS_CA_BUNDLE=$QUANTOTTO_CA_CERT python auto_install.py postinstall --target $1 --config-file $2.yaml
popd
PUSHD_FLAG=0

echo "*** Auto installation of Quantotto $1 target is complete ***"
