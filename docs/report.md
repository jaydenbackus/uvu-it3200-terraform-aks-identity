# Technical Report: Secure AKS with Terraform, Entra ID, and RBAC

**Course:** IT 3200 Cloud Computing
**Author:** Jayden Backus
**Repository:** https://github.com/jaydenbackus/uvu-it3200-terraform-aks-identity

> Lines marked **TODO** need results or screenshots from your own run. Put screenshots in `docs/screenshots/` and blur IDs you don't want public. Never show a secret.

## 1. Executive summary

I built an AKS cluster and a private container registry with Terraform, then gave each identity only the access its job needs. A service principal deploys the app into one namespace and nothing else. The nodes pull images with their own managed identity, which may pull but never push. No one holds a static admin password: the cluster's local accounts and the registry's admin user are both off, so every request goes through Microsoft Entra ID and Azure RBAC.

**TODO:** One sentence on the result (e.g. "The app ran from ACR on the first deploy; the main problem I hit was …").

## 2. Architecture overview

See [architecture.md](architecture.md). The design has two separate access paths:

- **Control path:** person or service principal → Entra ID → Azure RBAC → Kubernetes API.
- **Image path:** node kubelet → kubelet managed identity → AcrPull → ACR.

## 3. Terraform infrastructure

| File | Contents |
|---|---|
| `versions.tf` | AzureRM 4.x, AzureAD 3.x, and Time providers |
| `variables.tf` | Names, region, node size, namespace, and lab toggles |
| `main.tf` | Resource group, ACR (Basic, admin off, anonymous pull off), AKS (system-assigned identity, Entra + Azure RBAC, local accounts off) |
| `identity.tf` | App registration, service principal, 30-day client secret |
| `rbac.tf` | Every role assignment |
| `outputs.tf` | IDs and names; the secret is marked sensitive |

Three boolean variables let me reproduce failures without editing code: `grant_sp_cluster_access`, `enable_kubelet_acr_pull`, and `grant_user_bootstrap_admin`.

**"Private" registry.** The registry rejects anonymous pulls and has no admin password, so only Entra identities with an RBAC role can read it. It still has a public endpoint; a private endpoint would need the Premium SKU and a VNet, which costs more than this lab warrants.

**Evidence — TODO:**
- `screenshots/01-terraform-apply.png` — `terraform apply` summary
- `screenshots/02-aks-portal.png` — cluster overview, showing *Microsoft Entra ID authentication with Azure RBAC*
- `screenshots/03-acr-portal.png` — registry overview

## 4. Identity and access management

See [identities-and-permissions.md](identities-and-permissions.md) for the full table.

| Value | Where to find it |
|---|---|
| Tenant ID | `terraform output tenant_id` |
| Application (client) ID | `terraform output sp_client_id` |
| Service principal object ID | `terraform output sp_object_id` |

The service principal signs in with a client secret that expires after 30 days. Terraform generates it, so it sits in Terraform state; state and `tfvars` are git-ignored. In production I would replace the secret with workload identity federation (OIDC from GitHub Actions), which has no secret to leak.

**Why different identities?** Each identity does one job. A leaked deploy secret should not let an attacker pull every image or resize the cluster, and a compromised node should not be able to deploy workloads. Giving all of them the same rights would make the weakest credential as powerful as the strongest.

**Evidence — TODO:**
- `screenshots/04-sp-overview.png` — Enterprise application page (no secrets visible)
- `screenshots/05-sp-role-assignments.png` — `az role assignment list --assignee <sp_client_id> --all -o table`

## 5. AKS and ACR integration

```bash
az role assignment list --assignee "$(terraform -chdir=terraform output -raw kubelet_identity_client_id)" \
  --scope "$(az acr show -n "$ACR" --query id -o tsv)" -o table
```

**Why nodes need ACR access.** The kubelet on each node, not kubectl or the deployer, downloads the image. It authenticates as the kubelet managed identity, so that identity, and only that identity, needs AcrPull.

**Role research**

| Role | Finding |
|---|---|
| AcrPull | Pull images and read artifacts on a standard-RBAC registry. All the kubelet needs. |
| Container Registry Repository Reader | Replaces AcrPull on registries in *RBAC Registry + ABAC Repository Permissions* mode, where AcrPull is ignored. Can be limited to specific repositories with conditions. |
| AcrPush | Push and pull. Nodes never push, so this would be excess. |
| Contributor | Manage the registry resource: change SKU, settings, or delete it. Far more than pulling. |

**Investigation questions**

- *No pull permission:* the pod sits in `ErrImagePull`, then `ImagePullBackOff`. Events show `401 Unauthorized` or `failed to authorize`.
- *Auth failure vs. bad image name:* an auth failure says `unauthorized` / `401`. A wrong name or tag says `not found` / `manifest unknown`. A wrong registry hostname says `no such host`. `az acr repository show-tags` confirms whether the tag exists.
- *Why Terraform:* the assignment is reviewed in a pull request, recreated whenever the cluster is rebuilt (the kubelet identity changes), and removed on destroy. A manual assignment is forgotten, drifts, and outlives the cluster.

**Evidence — TODO:** `screenshots/06-kubelet-acrpull.png`

## 6. Service principal authentication testing

Run `scripts/sp-login.sh` then `scripts/test-access.sh service-principal`.

**First attempt (`grant_sp_cluster_access = false`) — TODO: paste exact errors**

```
az login --service-principal ...        → TODO (expected: success)
az aks get-credentials ...              → TODO (expected: AuthorizationFailed ... listClusterUserCredential/action)
```

**Diagnosis.** If `az login` succeeds and `az account show` shows `type: servicePrincipal`, the identity is valid. A later `AuthorizationFailed` or `Forbidden` means it lacks a role, not that it is broken. Azure answers "who are you?" (authentication) separately from "what may you do?" (authorization).

**After roles applied — TODO: fill in**

| Command | Result | Notes |
|---|---|---|
| `kubectl cluster-info` | TODO | |
| `kubectl get nodes` | TODO | Nodes are cluster-scoped; Reader/Writer may not cover them |
| `kubectl get namespaces` | TODO | |
| `kubectl get pods -A` | TODO | |
| `kubectl auth can-i create deployments -n it3200-lab` | TODO | expected `yes` |
| `kubectl auth can-i create deployments -n default` | TODO | expected `no` |
| `kubectl auth can-i delete namespaces` | TODO | expected `no` |

**Evidence — TODO:** `screenshots/07-sp-forbidden.png`, `screenshots/08-sp-success.png`

## 7. Personal account troubleshooting comparison

Workflow followed:

1. Recorded the service principal's exact error (Section 6).
2. Confirmed it authenticated: `az account show`.
3. Listed its roles: `az role assignment list --assignee <sp_client_id> --all -o table`.
4. Checked the cluster's auth mode: `az aks show -g $RG -n $AKS --query "{aad:aadProfile, localDisabled:disableLocalAccounts}"`.
5. Signed in as myself (`scripts/user-login.sh`) and ran the same tests.
6. Compared, fixed the service principal's roles in Terraform, and retested.

| Test | Service principal | Personal account |
|---|---|---|
| Azure authentication | TODO | TODO |
| Retrieve AKS credentials | TODO | TODO |
| List Kubernetes namespaces | TODO | TODO |
| Read Pods in lab namespace | TODO | TODO |
| Deploy application | TODO | TODO (expected: Forbidden; Reader only) |

**Difference:** TODO — name the role one identity had and the other lacked.

**Temporary permissions.** My account held *RBAC Cluster Admin* only long enough to create the namespace (`grant_user_bootstrap_admin = true`), then I removed it. **TODO:** screenshot of the role list before and after.

## 8. Kubernetes application deployment

```bash
scripts/build-and-push.sh
scripts/render-manifests.sh deployment.yaml service.yaml | kubectl apply -f -
kubectl get deployments,pods,services -n it3200-lab
kubectl describe pod -n it3200-lab -l app=hello-it3200
kubectl get events -n it3200-lab
kubectl port-forward -n it3200-lab svc/hello-it3200 8080:80
```

The `Successfully pulled image "acruvuit3200….azurecr.io/hello-it3200:v1"` event proves the node pulled from my private registry.

**Pod states**

| State | Meaning |
|---|---|
| `Pending` | Not yet scheduled (no node with enough CPU/memory) or waiting on volumes. |
| `ErrImagePull` | The latest pull attempt failed: auth, wrong name, or network. |
| `ImagePullBackOff` | Kubernetes is waiting longer between pull retries after repeated failures. |
| `CrashLoopBackOff` | The image pulled and the container started, but it keeps exiting. Check `kubectl logs --previous`. |

**Evidence — TODO:** `screenshots/09-acr-image.png`, `screenshots/10-pods-running.png`, `screenshots/11-pulled-event.png`, `screenshots/12-app-browser.png`

## 9. Permission and security analysis

**Why namespace-scoped write but no cluster delete?** A deploy pipeline needs to ship one app. If its credential leaks, the damage should stop at that app's namespace. Deleting the cluster is an Azure control-plane action that no deploy ever needs; granting it turns a leaked CI secret into an outage.

**Dev, test, and prod design**

- One cluster per environment (or at least prod on its own), each in its own subscription or resource group.
- One deploy identity per app per environment, with RBAC Writer only on that app's namespace.
- Humans get RBAC Reader in prod; write access goes through the pipeline or through just-in-time elevation (Entra PIM) with approval.
- Access is assigned to Entra groups, not individuals, so joiners and leavers are handled in one place.
- Prod images come from a prod registry that only accepts images promoted from test.

**Hardening applied:** local accounts off, ACR admin user off, anonymous pull off, non-root container, resource limits, 30-day secret.

## 10. Troubleshooting findings

### Problems I hit — TODO

| Symptom | Evidence | Root cause | Fix |
|---|---|---|---|
| TODO | | | |

### Scenario A — Authentication succeeds, kubectl returns Forbidden

- **Causes:** no Azure RBAC role for Kubernetes; role at the wrong scope (other namespace); role assigned to the app object instead of the service principal object; role not yet propagated; cluster uses Kubernetes RBAC so Azure roles are ignored.
- **Tools:** `az account show`, `az role assignment list --assignee <id> --all`, `kubectl auth can-i --list -n <ns>`, `az aks show --query aadProfile`.
- **Evidence:** the Forbidden message names the user (object ID), verb, and resource. Compare it with the role list.
- **Fix:** add the narrowest role that covers that verb and resource, through Terraform. Wait a few minutes, then retest.
- **Prevent:** a CI smoke test that runs `kubectl auth can-i` for each pipeline identity after every infra change.

### Scenario B — ImagePullBackOff

- **Causes:** AcrPull missing or on the wrong identity (cluster identity instead of kubelet); wrong registry, repo, or tag; registry firewall or private DNS blocking nodes; ABAC-mode registry needing Repository Reader.
- **Tools:** `kubectl describe pod`, `kubectl get events`, `az aks check-acr -g $RG -n $AKS --acr <login-server>`, `az acr repository show-tags`.
- **Evidence:** `401 Unauthorized` means permissions; `not found` means name or tag; `no such host` or timeouts mean network/DNS.
- **Fix:** assign AcrPull to the kubelet object ID at registry scope, or correct the image reference.
- **Prevent:** keep the assignment in the same Terraform module as the cluster; pin image tags; run `az aks check-acr` in the pipeline.

### Scenario C — Personal account works, service principal fails

- **Causes:** the user holds a role the service principal lacks (often inherited from subscription Owner); expired client secret; kubeconfig not converted to `spn` mode, so kubelogin still uses the user's token; env vars missing.
- **Tools:** `az role assignment list` for both identities side by side; `kubectl config view --minify` to see the kubelogin mode; Entra sign-in logs for the service principal.
- **Evidence:** a role present for one and absent for the other, or `AADSTS7000222` (expired secret).
- **Fix:** grant the missing role to the service principal in Terraform, or rotate the secret.
- **Prevent:** test with the pipeline identity, never a person's account; alert on secrets expiring within 7 days.

### Scenario D — "Give every service principal Cluster Admin"

- **Why not:** any leaked CI secret then owns every namespace, every Secret, and every RoleBinding. It removes the audit trail's meaning and breaks environment separation.
- **Instead:** find the exact verb and resource in the Forbidden error, grant that at the narrowest scope, and template the pattern so new apps get the right roles automatically.
- **Prevent:** an Azure Policy or CI check (e.g. Checkov, OPA/Conftest on the Terraform plan) that blocks Cluster Admin and Owner assignments to service principals.

### Scenario E — Terraform succeeds but the app won't start

- **Causes:** Terraform proves Azure resources exist, not that the workload runs. Image never pushed; image built for arm64 on an amd64 node (`exec format error`); container crashes; requests larger than node capacity; AcrPull not yet propagated.
- **Tools:** `kubectl get pods`, `describe`, `logs --previous`, `get events`, `kubectl top nodes`.
- **Evidence:** pod state points to the layer: `Pending` → scheduling, `ImagePullBackOff` → registry, `CrashLoopBackOff` → the app.
- **Fix:** depends on the layer; for arm64 builds, rebuild with `--platform linux/amd64`.
- **Prevent:** a post-deploy smoke test that waits on `kubectl rollout status` and curls the service before the pipeline reports success.

## 11. Bonus: break and fix

**TODO:** follow the README's bonus steps and record each.

1. `terraform apply -var enable_kubelet_acr_pull=false` — plan shows 1 to destroy. **TODO screenshot**
2. Pull-test pod events: **TODO** paste the `401 Unauthorized` / `ImagePullBackOff` lines.
3. `terraform apply` — plan shows 1 to add.
4. Pull-test pod pulls successfully. **TODO screenshot**

**Catching this before production:** `terraform validate` and `tflint` catch syntax; Checkov or Conftest on `terraform show -json tfplan` can require that every AKS cluster has an AcrPull assignment for its kubelet identity and forbid broad roles; and an ephemeral test environment can run `az aks check-acr` plus a real deploy and `rollout status` on each pull request.

## 12. Conclusion and lessons learned

- Authentication and authorization fail differently. A Forbidden error means the identity works but lacks a role.
- The deployer and the nodes are different identities. Granting ACR access to the wrong one changes nothing.
- `az aks get-credentials` succeeding proves only that you can download a kubeconfig.
- Role assignments take minutes to propagate; retest before changing more.
- **TODO:** one or two lessons from your own run.

**At scale (100 clusters, 500 apps).** I would define clusters, registries, and identities as Terraform modules so every cluster gets the same roles by default. Each app would get its own deploy identity using workload identity federation from CI (no secrets), scoped to its namespace and environment. Access would be granted to Entra groups and reviewed regularly; prod elevation would go through PIM. A few shared registries per environment would serve many clusters, with images promoted from test to prod. GitOps (Flux or Argo CD) would apply manifests so humans rarely need write access, and policy checks in CI would block overbroad roles before they reach Azure.

## 13. AI assistance

| What I asked | What it produced | How I checked it |
|---|---|---|
| Claude Code: scaffold the repo from the assignment text | Terraform, manifests, scripts, README, report outline | `terraform validate`; compared role names and AKS settings with Microsoft Learn and the Terraform registry docs; ran every command myself |
| **TODO** | | |

I am responsible for the configuration and confirmed each role's permissions against Microsoft's built-in role reference before applying it.
