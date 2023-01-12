#!/bin/bash
set -e
set -x

# Help function
help()
{
    echo "Usage: [ -a | --vault-address ]
       [ -r | --vault-role  ]
       [ -p | --vault-path ]
       [ -t | --vault-sa-ttl ]
       [ -c | --cluster-name ]
       [ -n | --cluster-namespace ]
       [ -h | --help]"
    exit 2
}

# Define arguments to be parsed
SHORT_ARGS="a:r:p:t:c:n:h"
LONG_ARGS="vault-address:,vault-role:,vault-path:,vault-sa-ttl:,cluster-name:,cluster-namespace:,help"

# Proccess arguments
OPTS=$(getopt -o $SHORT_ARGS --long $LONG_ARGS -u -- "$@")

# Print help if no arguments are provided
[[ "$#" -eq 0 ]] && help

eval set -- "$OPTS"
while [ : ]; do
    case "$1" in
        -a | --vault-address)       VAULT_ADDR="$2"; shift 2 ;;
        -r | --vault-role)          VAULT_ROLE=$2; shift 2 ;;
        -p | --vault-path)          VAULT_PATH=$2; shift 2 ;;
        -t | --vault-sa-ttl)        VAULT_SA_TTL=$2; shift 2 ;;
        -c | --cluster-name)        CLUSTER_NAME=$2; shift 2 ;;
        -n | --cluster-namespace)   CLUSTER_NAMESPACE=$2; shift 2 ;;
        -h | --help)                help; shift 2 ;;
        --)                         shift; break ;;
        *)                          echo "Unexpected argument $1"; help
    esac
done

# Required Arguments exit if empty
[[ -z $VAULT_ADDR ]] && { echo "-a|--vault-address is a required argument"; exit 1; }
[[ -z $VAULT_ROLE ]] && { echo "-r|--vault-role is a required argument"; exit 1; }

# Defaults if not provided
VAULT_PATH=${VAULT_PATH:-"jwt-github"}
VAULT_SA_TTL=${VAULT_SA_TTL:-"10m"}
CLUSTER_NAME=${CLUSTER_NAME:-"aks-plattform-int-nonprod-weu"}
CLUSTER_NAMESPACE=${CLUSTER_NAMESPACE:-"default"}


### Vault authentication
##
# Get token for this action
curl -sSL -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" "$ACTIONS_ID_TOKEN_REQUEST_URL" | \
jq "{ jwt: .value, role: \"$VAULT_ROLE\" }" > ./token.json
GITHUB_VAULT_TOKEN=$(jq -r '.jwt' token.json)

# Use github-token to get vault-token
VAULT_TOKEN=$(vault write -field=token auth/$VAULT_PATH/login role=$VAULT_ROLE jwt=$GITHUB_VAULT_TOKEN)

# Authenticate with vault with our new token
vault login token=$VAULT_TOKEN

# Create payload with required fields for POST request to Vault
jq --null-input \
--arg cluster_namespace "${CLUSTER_NAMESPACE}" \
--arg vault_cluster_role_binding "${CLUSTER_ROLE_BINDING}" \
--arg vault_sa_ttl "${VAULT_SA_TTL}" \
'{ "kubernetes_namespace": $cluster_namespace, "cluster_role_binding": $vault_cluster_role_binding, "ttl": $vault_sa_ttl }' \
> payload.json

# Get ServiceAccount for our cluster
# Create ServiceAccount and get token and name for created ServiceAccount
K8S_CREDS_REQUEST=$(curl --write-out '%{http_code}' -s -X POST -H "X-Vault-Token: ${VAULT_TOKEN}" --data @payload.json --output response.json "{{ '${{ secrets.PLATTFORM_VAULT_URL }}' }}/v1/kubernetes-${CLUSTER_NAME}/creds/${VAULT_ROLE}")
if [[ "${K8S_CREDS_REQUEST}" == "200" ]]
then
    SERVICE_ACCOUNT_NAME=$(cat response.json | jq -r '.data.service_account_name')
    SERVICE_ACCOUNT_TOKEN=$(cat response.json | jq -r '.data.service_account_token')
    shred -u response.json payload.json
else
    echo "http_code: ${K8S_CREDS_REQUEST}. Retrival of kubernetes credentials failed"
    shred -u payload.json
    exit 1
fi

### Kube-config setup
##
# Get secrets for our cluster
CLUSTER_INFO=$(vault read -format json secret/applications/shared/kubernetes-config/$CLUSTER_NAME | jq -r '.data')

# Get host of API-endpoint for cluster
CLUSTER_HOST=$(jq '.host' <<< "$CLUSTER_INFO")

# Get CA-Cert for cluster and base64 encode it (for portability)
CLUSTER_CA_CERT=$(jq '.ca_cert' <<< "$CLUSTER_INFO" | base64 -i -w 0)

# Use kubectl to create a config-file
kubectl config set-cluster $CLUSTER_NAME --server=$CLUSTER_HOST
kubectl config set clusters.$CLUSTER_NAME.certificate-authority-data $(echo $CLUSTER_CA_CERT)