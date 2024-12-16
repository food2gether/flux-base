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

# Cleanup
cleanup() {
  echo "Removing DNS resolver"
  case "$(uname -s)" in
      Darwin*)
        sudo rm -rf /etc/resolver/minikube-food2gether
        ;;
      MINGW64*)
        powershell.exe -Command "Get-DnsClientNrptRule | Where-Object { \$_.Namespace -eq '.$LOCAL_DOMAIN' } | Remove-DnsClientNrptRule -Force"
        ;;
      *)
        echo "Unsupported OS."
        echo "Skipping..."
        ;;
  esac
  minikube delete
}

# Install minikube & bootstrap flux

# make sure to create a fresh minikube cluster
minikube delete
minikube start --no-vtx-check
minikube addons enable ingress
minikube addons enable ingress-dns

trap cleanup EXIT

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
      powershell.exe -Command "Add-DnsClientNrptRule -Namespace '.$LOCAL_DOMAIN' -NameServers '$(minikube ip)'" # Required for application access
      ;;
    *)
      echo "Unsupported OS."
      echo "Skipping..."
      ;;
esac

echo "Patching cluster for local development..."
if [ -n "$application_component" ]; then
  flux suspend kustomization "$application_component" -n food2gether
  kubectl delete -k "k8s/deploy"
  kubectl apply -k "k8s/local"
fi
# Patch the local domain into it to expose domain via ingress-dns addon
kubectl patch ingress food2gether -n food2gether --type=json --patch='[{"op": "replace", "path": "/spec/rules/0/host", "value": "'"$LOCAL_DOMAIN"'"}]'
# Expose databasae for local development
# The database it gonna be available at $(minikube ip):5453
kubectl patch service postgresql-rw -n postgresql --type=json --patch='[{"op": "replace", "path": "/spec/externalIPs", "value": ["'"$(minikube ip)"'"]}]'

clear
echo ""
echo "Setup complete. You can now access the application at http://$LOCAL_DOMAIN/"
echo "The database is available at $(minikube ip):5453"
echo "Press Q to exit and remove the minikube cluster and dns resolver"
while true; do
  read -srn1 REPLY < /dev/tty
  if [[ $REPLY =~ ^[Qq]$ ]]; then
    break
  fi
done