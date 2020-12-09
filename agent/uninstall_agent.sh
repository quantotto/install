#!/bin/bash

set -e

trap onerror ERR

function onerror() {
    echo "Error uninstalling Quantotto Agent CLI"
}

echo "Uninstalling Quantotto Agent"

if [ -s /lib/systemd/system/qtoagent.service ]; then
    echo "Uninstalling qtoagent service"
    sudo systemctl stop qtoagent.service
    sudo systemctl disable qtoagent.service
    sudo rm -rf /lib/systemd/system/qtoagent.service
    echo "qtoagent service uninstalled"
fi

sudo rm -rf /etc/profile.d/quantotto.sh
sudo rm -rf /opt/quantotto
echo "Removed application files"



echo ""
echo "***********************************************************************"
echo "Quantotto Agent application was uninstalled."
echo ""
echo "Please logout / login to clear environment settings."
echo "***********************************************************************"
echo ""
