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
    echo "Usage $0 <target: k8s or standalone> <config name> <version>"
    exit 1
fi

if [ -z $2 ]; then
    echo "No config name specified"
    echo "Usage $0 <target: k8s or standalone> <config name> <version>"
    exit 1
fi

if [ -z $3 ]; then
    echo "No version specified"
    echo "Usage $0 <target: k8s or standalone> <config name> <version>"
    exit 1
fi

TARGET=$1
CONFIG_NAME=$2
VERSION=$3

if [ ! -e /opt/quantotto/.venv ] || [ ! -e /etc/profile.d/quantotto.sh ]; then
    pushd server/
    PUSHD_FLAG=1
    ./install_server.sh ${VERSION}
    popd
    PUSHD_FLAG=0
fi
source /etc/profile.d/quantotto.sh
if [ "${TARGET}" == "k8s" ]; then
    QUANTOTTO_CA_CERT=/opt/quantotto/certs/quantotto.crt
fi

pushd auto/
PUSHD_FLAG=1
python auto_install.py install --target ${TARGET} --config-file ${CONFIG_NAME}.yaml
REQUESTS_CA_BUNDLE=$QUANTOTTO_CA_CERT python auto_install.py postinstall --target ${TARGET} --config-file ${CONFIG_NAME}.yaml
popd
PUSHD_FLAG=0

echo "*** Auto installation of Quantotto v${VERSION} ${TARGET} target is complete ***"
