# Architecture

Two access paths run through this design. The **service principal** talks to the Kubernetes API. The **kubelet managed identity** pulls images from ACR. A role on one does nothing for the other.

```mermaid
flowchart TB
    subgraph Entra["Microsoft Entra ID (tenant)"]
        USER["👤 Personal user<br/>(comparison + one-time operator)"]
        SP["🤖 Service principal<br/>sp-uvu-it3200-*-deployer"]
    end

    subgraph RBAC["Azure RBAC role assignments (Terraform)"]
        R1["Cluster User Role<br/>scope: AKS cluster<br/><i>download kubeconfig</i>"]
        R2["RBAC Reader<br/>scope: AKS cluster<br/><i>read workloads</i>"]
        R3["RBAC Writer<br/>scope: namespace it3200-lab<br/><i>deploy app</i>"]
        R4["AcrPull<br/>scope: registry<br/><i>pull images only</i>"]
    end

    subgraph RG["Resource group rg-uvu-it3200-*"]
        subgraph AKS["AKS cluster aks-uvu-it3200-*"]
            API["Kubernetes API server<br/>Entra auth + Azure RBAC authz"]
            subgraph NS["Namespace it3200-lab"]
                DEP["Deployment hello-it3200<br/>2 Pods"]
                SVC["Service hello-it3200<br/>ClusterIP :80 → :8080"]
            end
            NODES["Node pool"]
            KUBELET["🔑 Kubelet managed identity"]
            CID["🔑 Cluster managed identity<br/>(manages Azure infra)"]
        end
        ACR["📦 ACR acruvuit3200*<br/>private, admin user off"]
    end

    USER -- "az login (interactive)" --> Entra
    SP -- "az login / kubelogin spn<br/>(client secret)" --> Entra
    SP --> R1 & R2 & R3
    USER --> R1 & R2
    R1 & R2 & R3 --> API
    API --> DEP --> SVC
    DEP -. scheduled on .-> NODES
    NODES -- runs as --> KUBELET
    KUBELET --> R4 --> ACR
    ACR -- "image hello-it3200:v1" --> NODES
```

## Reading the diagram

1. **Sign-in.** Every caller proves who it is to Entra ID. A person signs in through a browser; the service principal signs in with a client secret.
2. **Authorization.** Azure RBAC decides what the caller may do. *Cluster User Role* only lets you download the kubeconfig. The *RBAC Reader/Writer* roles decide what you may do inside Kubernetes.
3. **Deployment.** The service principal creates the Deployment and Service in `it3200-lab`, the only namespace where it can write.
4. **Image pull.** Each node's kubelet signs in to ACR as the kubelet managed identity. Its *AcrPull* role lets it download images and nothing else.

## Flows in plain words

| Flow | Who | Proves identity with | Allowed by |
|---|---|---|---|
| Get kubeconfig | Service principal or user | Entra token | Cluster User Role on the cluster |
| Read/write Kubernetes objects | Service principal or user | Entra token via kubelogin | AKS RBAC Reader / Writer |
| Pull image | Kubelet identity | Managed identity token (no secret) | AcrPull on the registry |
| Manage Azure infra (load balancers, disks) | Cluster identity | Managed identity token | Roles AKS assigns on the node resource group |
