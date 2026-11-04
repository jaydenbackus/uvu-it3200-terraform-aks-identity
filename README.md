# uvu-it3200-terraform-aks-identity

IT 3200 lab: an Azure Kubernetes Service (AKS) cluster and a private Azure Container Registry (ACR), built with Terraform and locked down with Microsoft Entra ID and Azure RBAC.

Terraform creates:

| Resource | Name | Purpose |
|---|---|---|
| Resource group | `rg-uvu-it3200-<student>` | Holds the lab resources |
| AKS cluster | `aks-uvu-it3200-<student>` | Runs the app. Entra ID sign-in, Azure RBAC for Kubernetes, local accounts off |
| Container registry | `acruvuit3200<student>` | Private image store. Admin user and anonymous pull off |
| Entra app + service principal | `sp-uvu-it3200-<student>-deployer` | Non-human identity that deploys to the cluster |
| Role assignments | see [docs/identities-and-permissions.md](docs/identities-and-permissions.md) | Least-privilege access for each identity |

See [docs/architecture.md](docs/architecture.md) for the diagram and [docs/report.md](docs/report.md) for the technical report.

## Repository layout

```
terraform/   AKS, ACR, identity, and role assignments
k8s/         Namespace, Deployment, Service, and a bonus pull-test Pod
app/         Sample web app (nginx, non-root, port 8080)
scripts/     Login, build, and access-test helpers
docs/        Architecture, identities, report, screenshots
```

## Prerequisites

- Azure subscription where you can create AKS, ACR, app registrations, and role assignments (Owner, or Contributor plus User Access Administrator).
- Terraform 1.6+, Azure CLI, kubectl, kubelogin, Docker (only if ACR Tasks is blocked).
- Install kubelogin with `brew install Azure/kubelogin/kubelogin` or `az aks install-cli`.

## Deploy

### 1. Provision the infrastructure

```bash
az login                                   # your personal account
cd terraform
cp terraform.tfvars.example terraform.tfvars   # set subscription_id and student_name
terraform init
terraform fmt -check
terraform validate
terraform plan -out tfplan
terraform apply tfplan
cd ..
source scripts/env-from-terraform.sh       # exports RG, AKS, ACR, NS, AZURE_* vars
```

AKS takes 5–10 minutes. Role assignments can take a few more minutes to take effect.

### 2. Create the namespace (one-time operator step)

Namespace-scoped roles cannot create the namespace they apply to, so your personal account gets a temporary admin role for this one step.

```bash
terraform -chdir=terraform apply -var grant_user_bootstrap_admin=true
scripts/user-login.sh
kubectl apply -f k8s/namespace.yaml
terraform -chdir=terraform apply -var grant_user_bootstrap_admin=false   # remove it
```

### 3. Push the image to ACR

```bash
scripts/build-and-push.sh
```

The script uses `az acr build` and falls back to a local `docker build` and `docker push`.

### 4. Test as the service principal

```bash
scripts/sp-login.sh
scripts/test-access.sh service-principal
```

To reproduce the Part 4 failure first, apply with `-var grant_sp_cluster_access=false`, run the same two scripts, record the errors, then apply again without the flag.

### 5. Deploy the app as the service principal

```bash
scripts/render-manifests.sh deployment.yaml service.yaml | kubectl apply -f -
kubectl rollout status deployment/hello-it3200 -n "$NS"
kubectl get deployments,pods,services -n "$NS"
kubectl describe pod -n "$NS" -l app=hello-it3200 | grep -A3 -i pulled
kubectl port-forward -n "$NS" svc/hello-it3200 8080:80   # open http://localhost:8080
```

### 6. Compare with your personal account

```bash
scripts/user-login.sh
scripts/test-access.sh personal-account
```

### Bonus: break and fix image pulls

```bash
terraform -chdir=terraform apply -var enable_kubelet_acr_pull=false
scripts/sp-login.sh
scripts/render-manifests.sh pull-test-pod.yaml | kubectl apply -f -
kubectl get events -n "$NS" --field-selector involvedObject.name=pull-test   # expect 401 / ImagePullBackOff
kubectl delete pod pull-test -n "$NS"

terraform -chdir=terraform apply                                           # restore AcrPull
scripts/render-manifests.sh pull-test-pod.yaml | kubectl apply -f -
kubectl get pod pull-test -n "$NS"                                         # expect Completed/Running
```

## Clean up

```bash
terraform -chdir=terraform plan -destroy
terraform -chdir=terraform destroy
az group show --name "$RG"                     # should return ResourceGroupNotFound
az ad sp list --display-name "sp-uvu-it3200"   # should return []
az logout
```

Destroy removes the cluster, registry, service principal, its secret, and every role assignment Terraform made. AKS also creates a node resource group (`MC_...`); deleting the cluster deletes it.

## Secrets

- The client secret lives only in Terraform state and in your shell's environment. `.gitignore` excludes state, `tfvars`, `.env`, and kubeconfig files.
- Read it with `terraform output -raw sp_client_secret` only when you need it. Never paste it into docs or screenshots.
- Before you push, run `git log -p | grep -iE "secret|password|client_secret"` and check the hits. If a secret leaks, delete it in Entra ID (or `terraform apply -replace=azuread_application_password.deployer`).
