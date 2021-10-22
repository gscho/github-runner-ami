#!/bin/bash

# Required or else we run into race conditions with apt
echo
echo "Waiting for cloud-init to finish ..."
cloud-init status --wait

echo 'debconf debconf/frontend select Noninteractive' | sudo debconf-set-selections

sudo apt-get update
sudo apt-get install -y jq curl awscli apt-transport-https ca-certificates gnupg lsb-release

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

sudo useradd actions -m -s /bin/bash
sudo mkdir -p /home/actions/runner

sudo groupadd -f docker
sudo usermod -append --groups docker actions

echo
echo "Downloading latest runner ..."

_LATEST_VERSION_LABEL=$(curl -s -X GET 'https://api.github.com/repos/actions/runner/releases/latest' | jq -r '.tag_name')
_LATEST_VERSION=$(echo ${_LATEST_VERSION_LABEL:1})
_RUNNER_FILE="actions-runner-linux-x64-${_LATEST_VERSION}.tar.gz"
_RUNNER_URL="https://github.com/actions/runner/releases/download/${_LATEST_VERSION_LABEL}/${_RUNNER_FILE}"

echo "Downloading ${_LATEST_VERSION_LABEL} for linux ..."
echo "${_RUNNER_URL}"

curl -O -L ${_RUNNER_URL}
ls -la *.tar.gz

echo
echo "Extracting ${_RUNNER_FILE} to /home/actions/runner"

sudo tar xzf "./${_RUNNER_FILE}" -C /home/actions/runner

sudo mkdir -p /home/actions/.aws
printf "[default]\nregion=${AWS_REGION}" | sudo tee /home/actions/.aws/credentials > /dev/null

sudo chown -R actions /home/actions

echo
echo "Enabling actions-runner ..."

sudo tee /etc/systemd/system/actions-runner.service > /dev/null << EOF
[Unit]
Description=Actions Runner

[Service]
User=actions
Type=oneshot
Environment="AWS_SM_SECRET_ID=${AWS_SM_SECRET_ID}"
Environment="AWS_SM_SECRET_NAME=${AWS_SM_SECRET_NAME}"
Environment="GITHUB_RUNNER_URL=https://github.com/${GITHUB_USERNAME}/${GITHUB_REPO}"
Environment="GITHUB_REPO=${GITHUB_REPO}"
Environment="GITHUB_USERNAME=${GITHUB_USERNAME}"
ExecStart=/bin/bash /home/actions/runner/start-runner.sh
ExecStop=/bin/bash /home/actions/runner/self-destruct.sh

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable actions-runner
