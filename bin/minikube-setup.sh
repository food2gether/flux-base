#!/bin/bash

# Fail on first error
set -e

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
  minikube delete
}

# Install minikube & bootstrap flux

# make sure to create a fresh minikube cluster
if ! minikube delete; then
  minikube delete
  sleep 5
fi

# Exposed ports:
# 80: http
# 443: https
# 5453: postgresql
DB_PORT=5432
#
# The service-node-port-range is set to 1-32767 to allow the database service to be patched as
# nodeport
minikube start \
  --driver=docker \
  --extra-config=apiserver.service-node-port-range=1-32767 \
  --ports=80:80 \
  --ports=443:443 \
  --ports="$DB_PORT:$DB_PORT" \
  --addons ingress

trap cleanup EXIT

flux bootstrap github --token-auth --owner=food2gether --repository=flux-base --branch=main --path=system <<< "$github_pat"
echo "";
echo "Cluster is set up!";
echo "";

echo "Patching cluster for local development..."
if [ -n "$application_component" ]; then
  flux suspend kustomization "$application_component" -n food2gether
  kubectl delete -k "k8s/deploy"
  kubectl apply -k "k8s/local"
fi

# Expose databasae for local development
# The database it gonna be available at localhost:5453
kubectl patch service postgresql -n food2gether --type=json --patch='[{"op": "replace", "path": "/spec/type", "value": "NodePort"}]'
kubectl patch service postgresql -n food2gether --type=json --patch='[{"op": "replace", "path": "/spec/ports/0/nodePort", "value": '$DB_PORT'}]'

clear
echo ""
echo "Setup complete. You can now access the application at http://localhost/"
echo "The database is available at postgres://username:password@localhost:$DB_PORT/food2gether" 
echo "Press Q to exit and remove the minikube cluster"
while true; do
  read -srn1 REPLY < /dev/tty
  if [[ $REPLY =~ ^[Qq]$ ]]; then
    break
  fi
done