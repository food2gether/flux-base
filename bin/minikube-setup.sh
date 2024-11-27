#!/bin/bash

# This is not needed for unix shells but here for consistency sake
FailGate() {
  if [ $? -ne 0 ]; then
    echo "Failed to execute command. Exiting..."
    exit 1
  fi
}

github_pat=$1
if [ -z "$github_pat" ]; then
  echo "Please provide a GitHub Personal Access Token as the first argument."
  exit 1
fi

# Install minikube & bootstrap flux

# We are storing the curl result in a variable because otherwise the stdin would be closed and the eval would not work resulting in a "curl: (23) Failed writing body" error
minikube_setup_script=$(curl --silent --fail https://raw.githubusercontent.com/food2gether/flux-base/refs/heads/main/bin/minikube-setup)
eval "$minikube_setup_script" <<< "$github_pat"

# Configure minikube dns
echo "Setup DNS resolver..."
case "$(uname -s)" in
    Darwin*)
      sudo mkdir -p /etc/resolver
      cat <<EOF | sudo tee /etc/resolver/minikube-food2gether > /dev/null
domain food2gether.local
nameserver $(minikube ip)
search_order 1
timeout 5
EOF
      ;;
    *)
      # Note: the read command needs a different flag on linux: -k1 -> -n1
      echo "Only MacOS is supported for now."
      echo "Skipping..."
      ;;
esac

if [ -n "$APPLICATION_COMPONENT" ]; then
  echo "Patching cluster to use local deployment..."
  flux suspend kustomization "$APPLICATION_COMPONENT" -n food2gether
  kubectl delete -k "deployment/prod"
  kubectl apply -k "deployment/local"
fi

clear
echo ""
echo "Setup complete. You can now access the application at http://food2gether.local/"
echo "Press Q to exit and remove the minikube cluster and dns resolver"
while true; do
  read -srn1 REPLY < /dev/tty
  if [[ $REPLY =~ ^[Qq]$ ]]; then
    break
  fi
done

# Cleanup
minikube delete
echo "Removing DNS resolver"
case "$(uname -s)" in
    Darwin*)
      sudo rm -rf /etc/resolver/minikube-food2gether
      ;;
    *)
      echo "Only MacOS is supported for now."
      echo "Skipping..."
      ;;
esac
