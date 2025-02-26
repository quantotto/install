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

supported_python_major="3"
supported_python_minor="6"
supported_ubuntu="16.04"
ACCOUNT=quantotto
CURRENT_ERROR_MSG="User ${ACCOUNT} doesn't exist or current user is not in ${ACCOUNT} group"
if id "${ACCOUNT}" >/dev/null 2>&1; then
    if [ -z "$(groups | grep quantotto)" ]; then
        echo -e "${RED}Please add current user to quantotto group${NC}"
        exit 1
    else
        echo -e "${GREEN}user ${ACCOUNT} check: success${NC}"
    fi
else
    echo -e "${RED}Please create user quantotto and add current user to  quantotto group${NC}"
    exit 1
fi


CURRENT_ERROR_MSG="Incompatible Python; should be ${supported_python}+"
echo "checking Python version"
pyver=`python3 -c "import sys; vi = sys.version_info; print(f'{vi.major}.{vi.minor}')"`
pyvermajor=`python3 -c "import sys; vi = sys.version_info; print(f'{vi.major}')"`
pyverminor=`python3 -c "import sys; vi = sys.version_info; print(f'{vi.minor}')"`
if awk 'BEGIN { exit !('${pyvermajor}' < '${supported_python_major}')}'; then
    echo -e "${RED}Incompatibe major Python version (${pyvermajor}); Should be ${supported_python_major}+${NC}"
    exit 1
fi
if awk 'BEGIN { exit !('${pyverminor}' < '${supported_python_minor}')}'; then
    echo -e "${RED}Incompatibe minor Python version (${pyverminor}); Should be ${supported_python_minor}+${NC}"
    exit 1
fi
echo -e "${GREEN}Python ${pyver} - success${NC}"

CURRENT_ERROR_MSG="Docker not found or not configured"
echo "checking docker"
docker -v
docker ps 1>/dev/null
echo -e "${GREEN}Docker - success${NC}"

CURRENT_ERROR_MSG="Incompatibe Ubuntu release; Should be ${supported_ubuntu}+"
echo "checking Ubuntu release"
distributor=`lsb_release -a 2>/dev/null | grep "Distributor ID:" | awk '{ print $3; }'`
if [ "${distributor}" != "Ubuntu" ]; then
    echo -e "${RED}Incompatibe OS distributor (${distributor}); Should be Ubuntu${NC}"
    exit 1
fi
ubuntu_release=`lsb_release -a 2>/dev/null | grep "Release:" | awk '{ print $2; }'`
if awk 'BEGIN { exit !('${ubuntu_release}' < '${supported_ubuntu}')}'; then
    echo -e "${RED}Incompatibe Ubuntu release (${ubuntu_release}); Should be ${supported_ubuntu}+${NC}"
    exit 1
fi
echo -e "${GREEN}Ubuntu ${ubuntu_release} - success${NC}"
