#!/bin/bash

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <cloud_port>"
    exit 1
fi

# Check if service was already configured (tunnerl.service exists)
if [ -f /etc/systemd/system/tunnel.service ]; then
    echo "SSH Tunnel service is already configured."
    exit 0
fi
echo "Setting up SSH Tunnel to portal.quantotto.io on port $1"

# generate ssh key pair without passphrase; overwrite existing keys if any
sudo mkdir -p /root/.ssh
# remove any existing keys to avoid interactive overwrite prompt
sudo rm -f /root/.ssh/id_rsa /root/.ssh/id_rsa.pub
# create a new RSA keypair with an empty passphrase
sudo ssh-keygen -t rsa -N "" -f /root/.ssh/id_rsa -q

sudo touch /root/.ssh/known_hosts
# delete old known hosts entry for portal.quantotto.io
sudo ssh-keygen -R portal.quantotto.io

# add portal.quantotto.io to known hosts to avoid prompts
# Use a tee with sudo because shell redirection (>>) runs as the calling user
# and would otherwise fail writing to a root-owned file.
ssh-keyscan -H portal.quantotto.io | sudo tee -a /root/.ssh/known_hosts >/dev/null

sudo tee /etc/systemd/system/tunnel.service > /dev/null << EOF
[Unit]
Description=SSH Tunnel with target server
After=network.target

[Service]
ExecStart=/usr/bin/ssh -NT -o ServerAliveInterval=60 -o ExitOnForwardFailure=yes -R 127.0.0.1:$1:localhost:22 -p 22 ubuntu@portal.quantotto.io
RestartSec=5
Restart=always

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable tunnel.service
sudo systemctl start tunnel.service

echo "SSH Tunnel setup complete. The service is running and will start on boot."
echo "Add the following public key to your portal.quantotto.io authorized_keys file:"
echo ""
sudo cat /root/.ssh/id_rsa.pub
echo ""
