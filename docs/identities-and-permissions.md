# Identities and permissions

## The four identities

| Identity | What it is | Credential | Used for |
|---|---|---|---|
| Personal Entra user | A human account | Password + MFA, interactive | Running Terraform, one-time namespace setup, comparison testing |
| Service principal (`sp-uvu-it3200-*-deployer`) | The tenant instance of an app registration | Client secret (30-day expiry, Terraform-managed) | Automated deploys to the cluster |
| AKS cluster managed identity | System-assigned identity owned by the cluster | None to manage; Azure issues tokens | Creating load balancers, disks, and node VMs |
| AKS kubelet managed identity | User-assigned identity AKS creates for the node pool | None to manage | Pulling images from ACR |

**Why separate identities?** Each one does one job, so each gets only that job's rights. If someone steals the deployer's secret, they cannot pull private images from other registries or resize the node pool. If a node is compromised, its kubelet identity can pull images but cannot change the cluster. Giving every identity the same broad rights would turn any single leak into a full compromise, and audit logs could no longer tell a person from a pipeline from a node.

## How the service principal authenticates

1. `az login --service-principal` sends the client ID, secret, and tenant ID to Entra ID and receives an Azure Resource Manager token.
2. `az aks get-credentials` uses that token to call `listClusterUserCredential`. The kubeconfig it returns holds no secret, only the cluster address and an exec hook for kubelogin.
3. `kubelogin convert-kubeconfig -l spn` rewrites the hook so kubelogin reads `AZURE_CLIENT_ID` and `AZURE_CLIENT_SECRET` and requests a token for the AKS server application.
4. The API server validates the token, then asks Azure RBAC whether this object ID may perform the request.

## Final role assignments

| Principal | Role | Scope | Why |
|---|---|---|---|
| Kubelet identity | AcrPull | Registry | Nodes must download private images. Pull only; no push, no delete. |
| Service principal | Azure Kubernetes Service Cluster User Role | Cluster | Download the user kubeconfig. Grants nothing inside Kubernetes. |
| Service principal | Azure Kubernetes Service RBAC Reader | Cluster | See workloads to verify deploys. No Secrets, no Roles. |
| Service principal | Azure Kubernetes Service RBAC Writer | `…/namespaces/it3200-lab` | Create and update Deployments, Services, and Pods in one namespace. |
| Personal user | Azure Kubernetes Service Cluster User Role | Cluster | Download the kubeconfig for comparison tests. |
| Personal user | Azure Kubernetes Service RBAC Reader | Cluster | Read-only comparison. |
| Personal user (temporary) | Azure Kubernetes Service RBAC Cluster Admin | Cluster | Create the namespace once. Removed right after; toggled by `grant_user_bootstrap_admin`. |

## Roles considered and rejected

| Role | Verdict |
|---|---|
| AcrPush | Includes pull, but also push. Nodes never push. Rejected. |
| Contributor (on ACR) | Lets the holder change or delete the registry. Rejected. |
| Container Registry Repository Reader | The right choice only when the registry uses *RBAC Registry + ABAC Repository Permissions* mode. In that mode AcrPull is not honored and this role, optionally limited to named repositories, replaces it. This lab uses standard RBAC. |
| AKS RBAC Admin | Can manage Roles and RoleBindings in its namespace, so the deployer could grant itself more. Rejected. |
| AKS RBAC Cluster Admin | Full control of every namespace and cluster-wide object. Only used briefly by the human operator. |
| Owner / Contributor on the cluster | Azure control-plane rights: delete the cluster, read admin credentials, change settings. Not needed to deploy. |

## Azure RBAC vs. Kubernetes RBAC

- **Azure RBAC for Kubernetes authorization** (used here): Role assignments live in Azure, are managed by Terraform with `azurerm_role_assignment`, and appear in the portal and in Azure audit logs. Scope can be the cluster or `<cluster-id>/namespaces/<name>`.
- **Native Kubernetes RBAC**: Role and RoleBinding objects live inside the cluster. With Entra integration, the binding's subject is the Entra object ID (or group ID). They must be applied with kubectl or the Terraform Kubernetes provider, and they are invisible to Azure tooling.

Both rely on Entra ID for sign-in. They differ only in where the "may this caller do this?" answer is stored.
