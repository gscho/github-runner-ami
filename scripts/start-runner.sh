#!/bin/bash

_GITHUB_TOKEN=$(aws secretsmanager get-secret-value --secret-id "${AWS_SM_SECRET_ID}" --query SecretString --output text | jq -r ".${AWS_SM_SECRET_NAME}")
_TOKEN=$(curl -u "$GITHUB_USERNAME:$_GITHUB_TOKEN" -X POST -H "Accept: application/vnd.github.v3+json" "https://api.github.com/repos/${GITHUB_USERNAME}/${GITHUB_REPO}/actions/runners/registration-token" | jq -r ".token")

cd /home/actions/runner
./config.sh --url "${GITHUB_RUNNER_URL}" --token "${_TOKEN}" --ephemeral --unattended --name $(hostname) --labels "ephemeral"
./run.sh