#!/bin/bash

# Helm Installer Script for Canonical Kubernetes
# by Calvin Hartwell

# Script is simplified version of spell
# https://raw.githubusercontent.com/conjure-up/spells/master/canonical-kubernetes/addons/common.sh

# Latest versions can be found here: 
# https://github.com/kubernetes/helm/releases

HELM_VERSION="v2.8.2"
PATH="$PATH:$HOME/bin"

if [[ $(uname -s) = "Darwin" ]]; then
   platform="darwin"
else
   platform="linux"
fi

helm_repo="https://storage.googleapis.com/kubernetes-helm"
helm_file="helm-$HELM_VERSION-$platform-amd64.tar.gz"
work_dir="$(mktemp -d)"

# Clean up previous helm version. 
rm -f "$HOME/bin/helm" "$HOME/bin/.helm"  # clear potentially different version

# Attempt to install Helm CLI tool 
echo "Installing Helm CLI"
curl -fsSL -o "$work_dir/$helm_file" "$helm_repo/$helm_file"
tar -C "$work_dir" -zxvf "$work_dir/$helm_file" 1>&2
mv "$work_dir/$platform-amd64/helm" "$HOME/bin/.helm"
chmod +x "$HOME/bin/.helm"

# Push the wrapper script to /usr/bin/helm
cat << 'EOF' > $HOME/bin/helm
  #!/bin/bash
  export KUBECONFIG="$HOME/.kube/config"
  "$HOME/bin/.helm" "$@"
EOF

chmod +x "$HOME/bin/helm"

echo "Deploying and initializing Helm"
init_count=1
        while ! helm init --upgrade; do
            if [[ "$init_count" -gt 5 ]]; then
                echo "Helm init failed"
                exit 1
            fi
            echo "Deploying and initializing Helm ($init_count/5)"
            ((init_count=init_count+1))
            sleep 5
        done

        echo "Waiting for tiller pods"
        wait_count=1
        while ! kubectl -n kube-system get po | grep -q 'tiller.*Running'; do
            if [[ "$wait_count" -gt 10 ]]; then
                echo "Tiller pods not ready"
                exit 1
            fi
            echo "Waiting for tiller pods ($wait_count/10)"
            ((wait_count=wait_count+1))
            sleep 30
        done
        echo "Tiller pods running"

# clean up. 
rm -rf "$work_dir"
