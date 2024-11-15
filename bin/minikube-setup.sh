#!/bin/sh

# This is not needed for unix shells but here for consistency sake
FailGate() {
  if [ $? -ne 0 ]; then
    echo "Failed to execute command. Exiting..."
    exit 1
  fi
}

# Install minikube & bootstrap flux
source bin/minikube-setup

# Configure minikube dns
case "$(uname -s)" in
    Darwin*)
        sudo mkdir -p /etc/resolver
        sudo <<EOF > /etc/resolver/minikube-food2gether
domain food2gether.local
nameserver $(minikube ip)
search_order 1
timeout 5
EOF
        ;;
    *)
        echo "Only MacOS is supported for now."
        ;;
esac


