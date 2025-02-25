# flux-base

This is the base repository for our FluxCD configuration files. It contains two main directories:
- `application`: Contains the configuration files for the application deployments. \
  The actual manifests of each service is stored in its own repository (under `/k8s/deploy/`) and is
  referenced here as a `kustomize.toolkit.fluxcd.io/v1/Kustomization` resource.
- `dev-infra`: Contains infrastructure components that are typically managed externally, but are
  required for the application to run. This includes for example the database.

## Usage

### Development
There is a script in `/bin/minikube-setup.sh` that will setup a minikube cluster with the necessary
components. Just run it like this:
```bash
bash bin/minikube-setup.sh $GITHUB_PAT
```
where `$GITHUB_PAT` is a GitHub Personal Access Token with the `repo` scope for this repository

Alternatively, you can do it manually:
```bash
minikube start \
  --driver=docker \
  --extra-config=apiserver.service-node-port-range=1-32767 \
  --ports=80:80 \
  --ports=443:443 \
  --ports="5432:5432" \
  --addons ingress
flux bootstrap github \
  --token-auth \
  --owner=food2gether \
  --repository=flux-base \
  --branch=main \
  --path=system <<< "$GITHUB_PAT"

# This will expose the database via a NodePort
kubectl patch service postgresql -n food2gether --type=json --patch='[{"op": "replace", "path": "/spec/type", "value": "NodePort"}]'
kubectl patch service postgresql -n food2gether --type=json --patch='[{"op": "replace", "path": "/spec/ports/0/nodePort", "value": 5432}]'
```

### Production

To deploy with production configuration, make sure you have a PostgreSQL database running.

To Configure the application, you first need to create a secret with the database config:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: food2gether-config
  namespace: flux-system # This is important, because the application is configured by flux via post build subsitution
type: Opaque
stringData:
  database_username: <username>
  database_password: <password>
  database_host: <host> # defaults to postgresql.food2gether.svc.cluster.local, highly recommended to change this to an ExternalName service
  database_port: <port> # defaults to 5432
  database_name: <name> # defaults to food2gether
```

Now, you can deploy the application:

By bootstraping it via flux:
```bash
flux bootstrap github \
  --token-auth \
  --owner=food2gether \
  --repository=flux-base \
  --branch=<branch> \
  --path=system
```

Or (recommended) by including the `Kustomization` in your own repository:
```yaml
---
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: food2gether
  # In flux-system namespace because we are referncing the flux-system secret witch cannot be accessed from other namespaces
  namespace: flux-system
spec:
  interval: 1m0s
  ref:
    branch: main
  secretRef:
    name: flux-system
  url: https://github.com/food2gether/flux-base.git
---
kind: Namespace
apiVersion: v1
metadata:
  name: food2gether
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: food2gether
  namespace: flux-system
spec:
  targetNamespace: food2gether
  # Checking for updates every 12 hours
  interval: 12h0m0s
  path: application/
  prune: false
  sourceRef:
    kind: GitRepository
    name: food2gether
    namespace: flux-system
  timeout: 2m0s
  wait: true
```

Helm-Chart will be avaliable at some time in somewhat distant future.
