#!/bin/bash

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <cloud_port>"
    exit 1
fi

sudo ssh-keygen -P "" -f /root/.ssh/id_rsa

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
sudo cat /root/.ssh/id_rsa.pub
echo ""
