#!/bin/bash

set -e

trap onerror ERR

function onerror() {
    echo "Error uninstalling Quantotto Server CLI"
}

echo "Uninstalling Quantotto"
if [ -s ${QUANTOTTO_HOME}/.env ] && [ -d ${VIRTUAL_ENV} ]; then
    qtoserver deployment stop 1>/dev/null
fi
sudo rm -rf /etc/profile.d/quantotto.sh
sudo rm -rf /opt/quantotto

docker network rm quantotto_network

echo ""
echo "***********************************************************************"
echo "Quantotto application was uninstalled."
echo "Docker images were not removed; use 'docker rmi ...' to delete them."
echo ""
echo "Please logout / login to clear environment settings."
echo "***********************************************************************"
echo ""
