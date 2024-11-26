#!/bin/bash

# This is not needed for unix shells but here for consistency sake
FailGate() {
  if [ $? -ne 0 ]; then
    echo "Failed to execute command. Exiting..."
    exit 1
  fi
}

# Install minikube & bootstrap flux

# We are storing the curl result in a variable because otherwise the stdin would be closed and the eval would not work resulting in a "curl: (23) Failed writing body" error
minikube_setup_script=$(curl --fail https://raw.githubusercontent.com/food2gether/flux-base/refs/heads/main/bin/minikube-setup)
eval "$minikube_setup_script"

# Configure minikube dns
case "$(uname -s)" in
    Darwin*)
      sudo mkdir -p /etc/resolver
      sudo cat <<EOF | tee /etc/resolver/minikube-food2gether > /dev/null
domain food2gether.local
nameserver $(minikube ip)
search_order 1
timeout 5
EOF
      ;;
    *)
      # Note: the read command needs a different flag on linux: -k1 -> -n1
      echo "Only MacOS is supported for now."
      exit 1
      ;;
esac

if [ -n "$APPLICATION_COMPONENT" ]; then
  echo "Patching cluster to use local deployment..."
  flux suspend kustomization "$APPLICATION_COMPONENT" -n food2gether
  kubectl delete -k "deployment/prod"
  kubectl apply -k "deployment/local"
fi

echo "Setup complete. You can now access the application at http://food2gether.local/"
echo "Press Q to exit and remove the minikube cluster and dns resolver"
while true; do
  read -srn1
  if [[ $REPLY =~ ^[Qq]$ ]]; then
    break
  fi
done

# Cleanup
minikube delete
case "$(uname -s)" in
    Darwin*)
      sudo rm -rf /etc/resolver/minikube-food2gether
      ;;
    *)
      echo "Only MacOS is supported for now."
      exit 1
      ;;
esac
