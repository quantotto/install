#!/bin/bash

set -e

trap onerror ERR

function onerror() {
    echo "Error installing Quantotto Agent CLI"
}

./precheck.sh


ACCOUNT=quantotto
APP_FOLDER=/opt/quantotto

echo "Updating system"
sudo apt-get -yy update && sudo apt-get -yy upgrade
