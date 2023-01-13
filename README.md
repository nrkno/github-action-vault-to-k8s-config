# Github action for creating a kubernetes config from vaults kubernetes auth endpoint
Github Action to create a kubernetes-config from vault kubernetes auth and secrets in vault. Can be used in k8s-set-context action. 
Created because the official hashicorp/vault action only supports `GET` requests, while the kubernetes auth method in vault uses `POST` requests.

## Inputs
```yaml
  vault-address:  
    description: 'address to your vault'
    required: true
  vault-role: 
    description: 'Your github applications vault role'
    required: true
  vault-path:
    description: 'Auth path for vault'
    default: jwt-github
    required: false
  cluster-name: 
    description: 'The name of your kubernetes cluster'
    required: true
  cluster-namespace:
    description: 'The name of your kubernetes namespace'
    required: true
  cluster-rolebinding:
    description: 'Rolebinding to give ServiceAccount in the cluster'
    required: false
    default: edit
  ca-cert-path:
    description: 'The path in vault to your secret containing the kubernetes ca cert of your cluster'
    required: true
  ca-cert-key:
    description: 'The secret key in ca-cert-path which contains the ca cert of your cluster'
    required: true
  cluster-host-path: 
    description: 'The path in vault to your secret containing the kubernetes api url of your cluster'
    required: true
  cluster-host-key: 
    description: 'The secret key in cluster-host-path which contains the api url of your cluster'
    required: true
```
## Outputs
```yaml
  k8s-config:
    description: 'The kube-config for your dynamic service account'
```

## Example usage:
```yaml
- uses: nrkno/github-action-vault-to-k8s-config
  id: vault-to-k8s-config
  with:
    vault-address: https://vault.your.com:8200
    vault-role: your-github-applications-vault-role
    cluster-name: your-cluster
    cluster-namespace: your-namespace
    ca-cert-path: path/to/secret/with/ca-cert/in/vault
    ca-cert-key: key-of-ca-cert-in-secret
    cluster-host-path: path/to/secret/with/api-url/in/vault
    cluster-host-key: key-of-api-url-in-secret
- uses: azure/k8s-set-context@v3
  with:
     method: kubeconfig
     kubeconfig: ${{ steps.vault-to-k8s-config.outputs.k8s-config }}
```

## Contributing
Create an issue and optionally a pull-request.
Use semantic commit messages.