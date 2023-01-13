FROM alpine:3.17.1

RUN apk --no-cache add coreutils util-linux-misc bash curl jq

# Download and install latest version of vault
RUN curl -L -o /tmp/vault.zip https://releases.hashicorp.com/vault/1.12.2/vault_1.12.2_linux_amd64.zip \
    && unzip /tmp/vault.zip -d /usr/local/bin/ \
    && rm -f /tmp/vault.zip

# Download and install latest version of kubectl
RUN KUBECTL_VERSION=$(curl --silent https://storage.googleapis.com/kubernetes-release/release/stable.txt) \
    && curl -L -o /usr/local/bin/kubectl https://dl.k8s.io/release/$KUBECTL_VERSION/bin/linux/amd64/kubectl \
    && chmod +x /usr/local/bin/kubectl

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]