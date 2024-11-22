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
        exit 1
        ;;
esac

if [ -n "$APPLICATION_COMPONENT" ]; then
  flux suspend kustomization "$APPLICATION_COMPONENT" -n food2gether
  kubectl delete -k "deployment/prod"
  kubectl apply -k "deployment/local"
fi

echo "Setup complete. You can now access the application at http://food2gether.local/"
echo "Press Q to exit and remove the minikube cluster and dns resolver"
while true; do
  read -n 1 -s -r; 
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
