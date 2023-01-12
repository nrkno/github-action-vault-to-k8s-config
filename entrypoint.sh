#!/bin/bash
set -e
set -x

# Help function
help()
{
    echo "Usage: [ -a | --vault-address ]
       [ -r | --vault-role  ]
       [ -p | --vault-path ]
       [ -c | --cluster-name ]
       [ -h | --help]"
    exit 2
}

# Define arguments to be parsed
SHORT_ARGS="a:r:p:c:h"
LONG_ARGS="vault-address:,vault-role:,vault-path:,cluster-name:,help"

# Proccess arguments
OPTS=$(getopt -o $SHORT_ARGS --long $LONG_ARGS -u -- "$@")

# Print help if no arguments are provided
[[ "$#" -eq 0 ]] && help

eval set -- "$OPTS"
while [ : ]; do
    case "$1" in
        -a | --vault-address)   VAULT_ADDR="$2"; shift 2 ;;
        -r | --vault-role)      VAULT_ROLE=$2; shift 2 ;;
        -p | --vault-path)      VAULT_PATH=$2; shift 2 ;;
        -c | --cluster-name)    CLUSTER_NAME=$2; shift 2 ;;
        -h | --help)            help; shift 2 ;;
        --)                     shift; break ;;
        *)                      echo "Unexpected argument $1"; help
    esac
done

# Required Arguments exit if empty
[[ -z $VAULT_ADDR ]] && { echo "-a|--vault-address is a required argument"; exit 1; }
[[ -z $VAULT_ROLE ]] && { echo "-r|--vault-role is a required argument"; exit 1; }

# Defaults if not provided
VAULT_PATH=${VAULT_PATH:-"jwt-github"}
CLUSTER_NAME=${CLUSTER_NAME:-"aks-plattform-int-nonprod-weu"}

# Get token for this action
curl -sSL -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" "$ACTIONS_ID_TOKEN_REQUEST_URL" | \
jq "{ jwt: .value, role: \"$VAULT_ROLE\" }" > ./token.json
GITHUB_VAULT_TOKEN=$(jq -r '.jwt' token.json)

# Use github-token to get vault-token
VAULT_TOKEN=$(vault write -field=token auth/$VAULT_PATH/login role=$VAULT_ROLE jwt=$GITHUB_VAULT_TOKEN)

# Authenticate with vault with our new token
vault login token=$VAULT_TOKEN

# Get secrets for our cluster
vault read secret/applications/shared/kubernetes-config/$CLUSTER_NAME