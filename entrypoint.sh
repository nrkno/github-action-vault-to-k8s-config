#!/bin/sh -l
set -e
set -x

export GITHUB_TOKEN=$1
export VAULT_ADDR=$2
export VAULT_ROLE=$3
export VAULT_AUDIENCE=$VAULT_URL

curl -sSL -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" "$ACTIONS_ID_TOKEN_REQUEST_URL" | \
jq "{ jwt: .value, role: \"$VAULT_ROLE\" }" > ./token.json
GITHUB_VAULT_TOKEN=$(jq -r '.jwt' token.json)

VAULT_TOKEN=$(vault write -field=token auth/jwt-github/login role=$3 jwt=$GITHUB_VAULT_TOKEN)
# VAULT_TOKEN=$(jq -r 'auth.client_token' $VAULT_RESPONSE)

vault login token=$VAULT_TOKEN

vault read secret/applications/shared/kubernetes-config/aks-plattform-int-nonprod-weu