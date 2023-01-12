#!/bin/bash
# set -e
# set -x

# Help function
help()
{
    echo "Usage: [ -a | --vault-address ]
      [ -r | --vault-role  ]
      [ -p | --vault-path ]
      [ -t | --vault-sa-ttl ]
      [ -c | --cluster-name ]
      [ -n | --cluster-namespace ]
      [ -b | --cluster-rolebinding ]
      [ -cp | --ca-cert-path ]
      [ -ck | --ca-cert-key ]
      [ -hp | --cluster-host-path ]
      [ -hk | --cluster-host-key ]
      [ -h | --help]"
    exit 2
}

# Some variables


# Define arguments to be parsed
SHORT_ARGS="a:r:p:t:c:n:b:cp:ck:hp:hk:h"
LONG_ARGS="vault-address:,vault-role:,vault-path:,vault-sa-ttl:,cluster-name:,cluster-namespace:\
    ,cluster-rolebinding:, ca-cert-path:, ca-cert-key: cluster-host-path:, cluster-host-key:,help"

# Proccess arguments
OPTS=$(getopt --options="$SHORT_ARGS" --longoptions="$LONG_ARGS" -u -- "$@")

# Print help if no arguments are provided
[[ "$#" -eq 0 ]] && help

eval set -- "$OPTS"
while [ : ]; do
    case "$1" in
        -a | --vault-address)       export VAULT_ADDR="$2"; shift 2 ;;
        -r | --vault-role)          export VAULT_ROLE=$2; shift 2 ;;
        -p | --vault-path)          export VAULT_PATH=$2; shift 2 ;;
        -t | --vault-sa-ttl)        export VAULT_SA_TTL=$2; shift 2 ;;
        -c | --cluster-name)        export CLUSTER_NAME=$2; shift 2 ;;
        -n | --cluster-namespace)   export CLUSTER_NAMESPACE=$2; shift 2 ;;
        -b | --cluster-rolebinding) export CLUSTER_ROLE_BINDING=$2; shift 2 ;;
        -cp | --ca-cert-path)       export CERT_PATH=$2; shift 2 ;;
        -ck | --ca-cert-key)        export CERT_KEY=$2; shift 2 ;;
        -hp | --cluster-host-path)  export HOST_PATH=$2; shift 2 ;;
        -hk | --cluster-host-key)   export HOST_KEY=$2; shift 2 ;;
        -h | --help)                help ;;
        --)                         shift; break ;;
        *)                          echo "Unexpected argument $1"; help
    esac
done

# Required Arguments exit if empty
[[ -z $VAULT_ADDR ]] && { echo "-a|--vault-address is a required argument"; exit 1; }
[[ -z $VAULT_ROLE ]] && { echo "-r|--vault-role is a required argument"; exit 1; }
[[ -z $CLUSTER_NAME ]] && { echo "-r|--cluster-name is a required argument"; exit 1; }
[[ -z $CLUSTER_NAMESPACE ]] && { echo "-r|--cluster-namespace is a required argument"; exit 1; }

# Defaults if not provided
VAULT_PATH=${VAULT_PATH:-"jwt-github"}
VAULT_SA_TTL=${VAULT_SA_TTL:-"10m"}
CLUSTER_ROLE_BINDING=${CLUSTER_ROLE_BINDING:-"edit"}
export KUBECONFIG="${RUNNER_TEMP}/kube-config"


### Vault authentication
##
# Get token for this action
GITHUB_TOKEN=$(curl -sSL -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" "$ACTIONS_ID_TOKEN_REQUEST_URL" | jq -r ".value")

# Use github-token to get vault-token
GITHUB_VAULT_TOKEN=$(vault write -field=token auth/$VAULT_PATH/login role=$VAULT_ROLE jwt=$GITHUB_TOKEN)

# Authenticate with vault with our new token
export VAULT_TOKEN=$(vault login -token-only token=$GITHUB_VAULT_TOKEN)

# Get ca-cert and api-host for our cluster
CLUSTER_HOST=$(vault read -field=$HOST_KEY $HOST_PATH)
CLUSTER_CA_CERT=$(vault read -field=$CERT_KEY $CERT_PATH | base64 -i -w 0)

# write to vault with required fields for credentials to kubernetes
K8S_CREDS_REQUEST=$(vault write --format=json kubernetes-${CLUSTER_NAME}/creds/${VAULT_ROLE}-${CLUSTER_ROLE_BINDING} \
    kubernetes_namespace="${CLUSTER_NAMESPACE}" \
    cluster_role_binding="false" \
    ttl="${VAULT_SA_TTL}")

# Unset variables we are done with
unset GITHUB_VAULT_TOKEN
unset VAULT_TOKEN

# Get host of API-endpoint for cluster
SERVICE_ACCOUNT_NAME=$(jq -r '.data.service_account_name' <<< "$K8S_CREDS_REQUEST")

# Get CA-Cert for cluster and base64 encode it (for portability)
SERVICE_ACCOUNT_TOKEN=$(jq -r '.data.service_account_token' <<< "$K8S_CREDS_REQUEST")

# Unset variables we are done with
unset K8S_CREDS_REQUEST

echo CLUSTER_HOST $CLUSTER_HOST
echo SERVICE_ACCOUNT_NAME $SERVICE_ACCOUNT_NAME
echo SERVICE_ACCOUNT_TOKEN $SERVICE_ACCOUNT_TOKEN

# Create cluster
kubectl config set clusters $CLUSTER_NAME --server=$CLUSTER_HOST

# Set CA-Cert for our cluster
kubectl config set clusters.$CLUSTER_NAME.certificate-authority-data $(echo $CLUSTER_CA_CERT)

# Define credentials to use for our cluster
kubectl config set-credentials $SERVICE_ACCOUNT_NAME --token="$SERVICE_ACCOUNT_TOKEN"

# Create context to join cluster, credentials and namespace
kubectl config set-context $CLUSTER_NAME --cluster="$CLUSTER_NAME" --user="$SERVICE_ACCOUNT_NAME" --namespace="$CLUSTER_NAMESPACE"

# Unset variables we are done with
unset CLUSTER_CA_CERT
unset SERVICE_ACCOUNT_NAME
unset SERVICE_ACCOUNT_TOKEN
unset CLUSTER_NAMESPACE

# Output kube-config
echo 'k8s-config<<EOF' >> $GITHUB_OUTPUT
cat $KUBECONFIG >> $GITHUB_OUTPUT
echo 'EOF' >> $GITHUB_OUTPUT

unset KUBECONFIG
