#!/bin/bash

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
CURRENT_ERROR_MSG=""
function onerror() {
    echo -e "${RED}${CURRENT_ERROR_MSG} $?${NC}"
    exit 1
}

trap onerror ERR
