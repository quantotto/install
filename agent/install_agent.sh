#!/bin/bash

set -e

trap onerror ERR

function onerror() {
    echo "Error installing Quantotto Agent CLI"
}

./precheck.sh

