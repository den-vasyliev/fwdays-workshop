# Install Homebrew
yes|/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"&&eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"


# Install Terraform, Flux, and htop using Homebrew
yes|brew install opentofu fluxcd/tap/flux kind derailed/k9s/k9s age sops

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

# Create alias for kubectl and command-line autocompletion
alias k=kubectl

# Enable kubectl and Flux command-line autocompletion for Zsh
. <(kubectl completion zsh)
. <(flux completion zsh)

# Install flux and tf-controller

flux install

# Create a HelmRepository and HelmRelease resources for the tf-controller Helm chart

flux create source helm tf-controller --url=oci://ghcr.io/flux-iac/charts --interval=1h0s -n flux-system --export
flux create source helm tf-controller --url=oci://ghcr.io/flux-iac/charts --interval=1h0s -n flux-system


# Create helm release tf-controller
flux create source helm tf-controller --url=oci://ghcr.io/flux-iac/charts --interval=1h0s -n flux-system
flux create hr tf-controller -n flux-system --interval=5m --source=HelmRepository/tf-controller --chart=tf-controller --chart-version="0.16.0-rc.4" --crds CreateReplace 


## Explore terrafrom code for tls keys module

https://github.com/den-vasyliev/fwdays-workshop/blob/tf-controller/tf-gke-cluster/tf-tls-keys-gr.yaml
https://github.com/den-vasyliev/tf-hashicorp-tls-keys

## terrafrom CR
https://github.com/den-vasyliev/fwdays-workshop/blob/tf-controller/tf-gke-cluster/tls-keys-tf.yaml


## Explore terrafrom code for GKE cluster with gpu

https://github.com/den-vasyliev/fwdays-workshop/blob/tf-controller/tf-gke-cluster/main.tf


# Prepare the SOPS secret
## Generate a new age key
age-keygen -o ~/.ssh/age-key.txt

## Create a Kubernetes secret for the age key
cat ~/.ssh/age-key.txt |
k create secret generic sops-age \
--namespace=flux-system \
--from-file=age.agekey=/dev/stdin

## Export the public key
AGE_PUB_KEY=age1lxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx


# Create a Kubernetes secret for GCP authentication
## Create service account
## Create a service account key
## Create a Kubernetes secret for the service account key

k create secret -n flux-system  generic k8s-k3s-secret --from-file=credentials=../../GCP_PROJECT.json -o yaml --dry-run=client>gcp-auth-secret.yaml

## Encrypt the secret using SOPS and the age key
sops --age=$AGE_PUB_KEY --encrypt --encrypted-regex '^(data|stringData)$' --in-place gcp-auth-secret.yaml

## Enable decription in flux with kustomization.yaml patch
  decryption:
    provider: sops
    secretRef:
      name: sops-age


# Terraform with GitOps
## Create git source for the tf-config repository
flux create source git tf-config -n flux-system --url=https://github.com/den-vasyliev/fwdays-workshop --branch=tf-controller --interval=5m --export

## Create kustomization for the tf-config repository
flux bootstrap git \
  --url=https://github.com/den-vasyliev/fwdays-workshop \
  --branch=tf-controller \
  --path=tf-gke-cluster \
  --token-auth

k get tf -A

## Bootstrap the ollama setup on new cluster
# finally apply 

# flux create source git ollama -n default --url=https://github.com/den-vasyliev/fw-non-prod --branch=main --interval=5m --export
# flux create source git ollama -n default --url=https://github.com/den-vasyliev/fw-non-prod --branch=main --interval=5m


# On new cluster
flux bootstrap git \
  --url=https://github.com/den-vasyliev/fw-non-prod \
  --branch=main \
  --path=clusters/my-cluster \
  --token-auth --export

flux get all -A --status-selector ready=false
