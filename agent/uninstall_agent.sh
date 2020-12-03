#!/bin/bash

set -e

trap onerror ERR

function onerror() {
    echo "Error uninstalling Quantotto Agent CLI"
}

echo ""
echo "***********************************************************************"
echo "Quantotto application was uninstalled."
echo ""
echo "Please logout / login to clear environment settings."
echo "***********************************************************************"
echo ""
