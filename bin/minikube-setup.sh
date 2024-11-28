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
      ;;
    MINGW64*)
      powershell.exe -Command "Get-DnsClientNrptRule | Where-Object { $_.Namespace -eq '$LOCAL_DOMAIN' } | Remove-DnsClientNrptRule -Force"
      powershell.exe -Command "Add-DnsClientNrptRule -Namespace '$LOCAL_DOMAIN' -NameServers '$(minikube ip)'"
      ;;
    *)
      # Note: the read command needs a different flag on linux: -k1 -> -n1
      echo "Unsupported OS."
      echo "Skipping..."
      ;;
esac
minikube tunnel &
TUNNEL_PID=$!

if [ -n "$application_component" ]; then
  echo "Patching cluster to use local deployment..."
  flux suspend kustomization "$application_component" -n food2gether
  kubectl delete -k "deployment/prod"
  kubectl apply -k "deployment/local"
fi

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

kill $TUNNEL_PID
# Cleanup
echo "Removing DNS resolver"
case "$(uname -s)" in
    Darwin*)
      sudo rm -rf /etc/resolver/minikube-food2gether
      ;;
    MINGW64*)
      powershell.exe -Command "Remove-DnsClientNrptRule -Namespace '$LOCAL_DOMAIN' -NameServer '$(minikube ip)'"
      ;;
    *)
      echo "Unsupported OS."
      echo "Skipping..."
      ;;
esac
minikube delete

