#!/bin/bash

# Fail on first error
set -e

LOCAL_DOMAIN="food2gether.test"

github_pat=$1
application_component=$2

if [ -z "$github_pat" ]; then
  echo "Please provide a GitHub Personal Access Token as the first argument."
  exit 1
fi

if [ -z "$application_component" ]; then
  echo "application_component is omitted. The cluster will be set up with production configuration."
fi

# Install minikube & bootstrap flux

# make sure to create a fresh minikube cluster
minikube delete
minikube start --addons storage-provisioner,ingress,ingress-dns

flux bootstrap github --token-auth --owner=food2gether --repository=flux-base --branch=main --path=system <<< "$github_pat"
echo "";
echo "Cluster is set up!";
echo "";

# Configure minikube dns
echo "Setup DNS resolver..."
case "$(uname -s)" in
    Darwin*)
      sudo mkdir -p /etc/resolver
      cat <<EOF | sudo tee /etc/resolver/minikube-food2gether > /dev/null
domain $LOCAL_DOMAIN
nameserver $(minikube ip)
search_order 1
timeout 5
EOF
      cat <<EOF | sudo tee /etc/resolver/minikube-cluster-local> /dev/null
domain cluster.local
nameserver $(minikube ip)
search_order 1
timeout 5
EOF
      ;;
    MINGW64*)
      powershell.exe -Command "Add-DnsClientNrptRule -Namespace '.$LOCAL_DOMAIN' -NameServers '$(minikube ip)'" # Required for application access
      powershell.exe -Command "Add-DnsClientNrptRule -Namespace '.cluster.local' -NameServers '$(minikube ip)'" # Required for kubernetes service resolution
      ;;
    *)
      echo "Unsupported OS."
      echo "Skipping..."
      ;;
esac

echo "Patching cluster to use local deployment..."
if [ -n "$application_component" ]; then
  flux suspend kustomization "$application_component" -n food2gether
  kubectl delete -k "deployment/prod"
  kubectl apply -k "deployment/local"
fi
kubectl patch ingress food2gether -n food2gether --type=json -p='[{"op": "replace", "path": "/spec/rules/0/host", "value": "'"$LOCAL_DOMAIN"'"}]'

clear
echo ""
echo "Setup complete. You can now access the application at http://$LOCAL_DOMAIN/"
echo "Press Q to exit and remove the minikube cluster and dns resolver"
while true; do
  read -srn1 REPLY < /dev/tty
  if [[ $REPLY =~ ^[Qq]$ ]]; then
    break
  fi
done

# Cleanup
echo "Removing DNS resolver"
case "$(uname -s)" in
    Darwin*)
      sudo rm -rf /etc/resolver/minikube-food2gether
      ;;
    MINGW64*)
      powershell.exe -Command "Get-DnsClientNrptRule | Where-Object { \$_.Namespace -eq '.$LOCAL_DOMAIN' -or \$_.Namespace -eq '.cluster.local' } | Remove-DnsClientNrptRule -Force"
      ;;
    *)
      echo "Unsupported OS."
      echo "Skipping..."
      ;;
esac
minikube delete

