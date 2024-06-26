# Install Homebrew
yes|/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"&&eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# Install Terraform, Flux, and htop using Homebrew
yes|brew install kubectx opentofu fluxcd/tap/flux htop kind derailed/k9s/k9s kubeseal

# Initialize kind cluster
cat <<EOF >> kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
- role: worker
EOF
#
kind create cluster --config kind-config.yaml

# Use k9s to explore the cluster
k9s

# Run your environment
zsh
# Enable kubectl autocompletion
alias k=kubectl
source <(kubectl completion zsh)

# Enable Flux command-line autocompletion for Zsh https://fluxcd.io/flux/cmd/
. <(flux completion zsh)

# Install metrics-server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.5.0/components.yaml

# Change tls configuration to make it work with kind
#      - args:
#        - --kubelet-insecure-tls

# Resources for the Ollama and WebOpenUI projects
#https://artifacthub.io/packages/helm/ollama-helm/ollama
#https://github.com/open-webui/open-webui
#https://github.com/open-webui/helm-charts

flux install

# Create flux resources for the Ollama project https://github.com/otwld/ollama-helm/blob/main/values.yaml

# dry-run
flux create source helm ollama-chart --url=https://otwld.github.io/ollama-helm/ --interval=10m --export

# imperative command to create the source
flux create source helm ollama-chart --url=https://otwld.github.io/ollama-helm/ --interval=10m -n default

# check the resources
k get helmrepositories.source.toolkit.fluxcd.io -A

# imperative command to create the helm release https://fluxcd.io/flux/cmd/flux_create_helmrelease/
flux create hr ollama -n default --interval=10m --source=HelmRepository/ollama-chart --chart=ollama --chart-version="0.37.0"

# check the resources
flux stats

#add sealed-secrets controller 
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.27.0/controller.yaml

#install kubeseal manager
brew install kubeseal

kubectl create secret generic openwebui-secret-values --from-file=values.yaml=./values.yaml --dry-run=client -o yaml > openwebui-secret.yaml
kubeseal < openwebui-secret.yaml > mysealedsecret.yaml
kubectl apply -f mysealedsecret.yaml

# openwebui 
# copy values.yaml https://github.com/open-webui/helm-charts/blob/main/charts/open-webui/values.yaml
# create sealedsecret with values.yaml

kubectl create secret generic openwebui-secret-values --from-file=values.yaml=./values.yaml --dry-run=client -o yaml > openwebui-secret.yaml
kubeseal < openwebui-secret.yaml > mysealedsecret.yaml
kubectl apply -f mysealedsecret.yaml

# create git source
flux create source git -n default openwebui --url=https://github.com/open-webui/helm-charts --branch=main
# create helm release
flux create hr openwebui -n default --interval=10m --source=GitRepository/openwebui --chart=./charts/open-webui --values-from=Secret/openwebui-secret-values
# check the resources
k get svc
# open the webui
k port-forward svc/open-webui 8080:80
#https://ollama.com/library

# Chose the right model for the job
# https://ollama.com/library

# Pipelines https://github.com/open-webui/pipelines
# Try to configure the pipeline for the Ollama project:
# - wiki
# - time function
# - langfuse trace filter
# - run python code
# - rag and document
# - audio and video
# - code review
