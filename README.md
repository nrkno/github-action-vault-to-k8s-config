# vault-to-k8s-config
Github Action to create a kubernetes-config from vault kubernetes auth and secrets in vault. Can be used in k8s-set-context action. 
Created because the official hashicorp/vault action only supports `get` requests, while the kubernetes auth method in vault uses a POST request.

### Example usage:
```yaml
- uses: nrkno/vault-to-k8s-config
  id: vault-to-k8s-config
  with:
     vault-url: https://localhost:8200
     vault-role: your-vault-role
     cluster: your-cluster
     namespace: your-namespace
     ca-cert: path/in/vault/to/secret/named-secret-with-ca-cert
     k8s-api-url: path/in/vault/to/secret/named-secret-with-k8s-api-url
     kubernetes-creds: path/in/vault/to/k8s-auth/endpoint/
- uses: azure/k8s-set-context@v3
  with:
     method: kubeconfig
     kubeconfig: ${{ steps.vault-to-k8s-config.outputs.k8s-config }}
```
