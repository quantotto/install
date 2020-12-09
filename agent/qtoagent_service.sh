#!/bin/bash

export OAUTHLIB_INSECURE_TRANSPORT=yes
export QUANTOTTO_HOME=/opt/quantotto
source /opt/quantotto/.venv/bin/activate
qtoagentservice
