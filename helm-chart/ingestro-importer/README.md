<p align="center">
  <a href="https://ingestro.com/" rel="noopener" target="_blank"><img width="150" src="https://s3.eu-central-1.amazonaws.com/general-upload.ingestro.com/ingestro_logo_darkblue.svg" alt="Ingestro logo"></a>
</p>

# Ingestro-importer Helm Chart Guide

This chart deploys the complete Ingestro Importer backend (Importer API, Mapping API, AI Service, MongoDB, ingress routing, and supporting secrets) into any Kubernetes cluster with a single `helm install`. It mirrors the production setup we ship to customers: probes, ingress rewrites, registry secrets, ConfigMap/Secret managed env vars, and optional autoscaling settings are already baked in.

---

## 1. Prerequisites

| Requirement              | Notes                                                                                                                                                                  |
| ------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Kubernetes 1.24+ cluster | EKS, AKS, GKE, OpenShift, Rancher, or any CNCF distribution                                                                                                            |
| `kubectl` & Helm 3.9+    | `helm version`, `kubectl version` should succeed and point to the target cluster                                                                                       |
| Docker Hub credentials   | username must be `getnuvo`, PAT with pull access to `getnuvo/*` images                                                                                                 |
| Domain / DNS entry       | External traffic should land on the ingress controller; create a DNS record (e.g. `importer.customer.com`) pointing to the controller’s load balancer                  |
| Ingress controller       | Most managed clusters ship an ingress solution. If not, install one (e.g. AWS Load Balancer Controller, nginx ingress, Traefik). Examples below use nginx for clarity. |

---

## 2. Configure your values

Create your own override file (for example `values.develop.yaml`). Use the `values.yaml` as a template (provided in the repository).

Key points to consider:

| Section                              | Key                                             | Purpose                                                                                 |
| ------------------------------------ | ----------------------------------------------- | --------------------------------------------------------------------------------------- |
| `importer/mapping/aiService.image.*` | Use fixed tags instead of `latest`              | Keep releases deterministic                                                             |
| `gateway.hosts`                      | Change `importer.local` to your domain          | Point the gateway at your DNS                                                           |
| `mappingGateway.hosts`               | Change `importer.local` to your domain          | Point the gateway at your DNS. It should be the same as `gateway.hosts`                 |
| `livenessProbe/readinessProbe`       | Adjust timings or disable in dev                | Align probes with your env                                                              |
| `global.licenseKey`                  | Change with your Ingestro Pipelines License Key | Centralize license delivery. Set once to avoid setting it for each service individually |

### Secret handling (inline, existing, or ExternalSecret)

Each workload (importer, mapping, aiService) supports three approaches:

1. **Inline secrets** (default) via the `*.secrets` block (plus `global.licenseKey`). Helm renders an Opaque Secret in the namespace.
2. **Reference a pre-created secret** by setting `*.secretRef.existingSecret`. Use this when another tool (e.g. AWS Secrets Manager + External Secrets Operator) already populates a Kubernetes `Secret`.
3. **Ask the chart to create an ExternalSecret** by enabling `*.externalSecret`. This renders an [`ExternalSecret`](https://external-secrets.io/latest/introduction/) resource that syncs from your `SecretStore`/`ClusterSecretStore` into the same secret that pods consume.

Example: sourcing importer credentials from AWS Secrets Manager via External Secrets Operator:

```yaml
importer:
  externalSecret:
    enabled: true
    name: importer-license-external
    refreshInterval: 1h
    secretStoreRef:
      name: aws-ssm
      kind: ClusterSecretStore
    target:
      name: ingestro-importer-importer-secret
      creationPolicy: Owner
    data:
      - secretKey: IMPORTER_LICENSE_KEY
        remoteRef:
          key: /nuvo/importer
          property: license
      - secretKey: IMPORTER_AWS_ACCESS_KEY
        remoteRef:
          key: /nuvo/importer
          property: awsAccessKey
      - secretKey: IMPORTER_AWS_SECRET_KEY
        remoteRef:
          key: /nuvo/importer
          property: awsSecretKey
```

Repeat for `mapping.externalSecret` or `aiService.externalSecret` if those secrets live in AWS as well. If you already create ExternalSecrets outside this chart, leave `externalSecret.enabled=false` and set `secretRef.existingSecret` to the name of the resulting Kubernetes `Secret`.

> **Prerequisite:** enabling `*.externalSecret` assumes the [External Secrets Operator](https://external-secrets.io/latest/introduction/) CRDs are installed in your cluster and a `SecretStore`/`ClusterSecretStore` is configured to talk to AWS Secrets Manager or Parameter Store.

#### Docker registry credentials via ExternalSecret

Pods from every component reuse the same image pull secret. You can still provide credentials inline (set `global.imageCredentials.create=true` plus `username/password`) or precreate a secret and list it under `global.imagePullSecrets`. To mirror the behaviour of the workload secrets, the chart can now render an `ExternalSecret` that populates the Docker config:

```yaml
global:
  imageCredentials:
    externalSecret:
      enabled: true
      secretStoreRef:
        name: aws-ssm
        kind: ClusterSecretStore
      target:
        name: my-registry-pull-secret
      data:
        - secretKey: .dockerconfigjson
          remoteRef:
            key: /nuvo/docker
```

Make sure the upstream secret contains a valid `.dockerconfigjson` entry (base64-encoded JSON with your registry credentials). Every workload automatically references the resulting Kubernetes `Secret`, so no extra per-component wiring is required.

### Gateway and mapping ingress annotations and CORS

Both ingress layers now expose optional CORS flags. Set `gateway.cors.enable` and/or `mappingGateway.cors.enable` to `true` if browsers call the `/sdk/v1`, `/sdk/service`, or `/sdk/mapping` endpoints directly.

```yaml
gateway:
  cors:
    enable: true
    allowOrigin: "*"
    allowMethods: "GET,POST,PUT,DELETE,OPTIONS"
    allowHeaders: "DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization"
    allowCredentials: "true"
mappingGateway:
  cors:
    enable: true
    allowOrigin: "*"
    allowMethods: "GET,POST,PUT,DELETE,OPTIONS"
    allowHeaders: "DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization"
    allowCredentials: "true"
```

The chart injects the appropriate nginx ingress annotations when these blocks are enabled; adjust values to tighten security (e.g. restrict origins).

---

## 3. Install or reuse an ingress controller

If you already run an ingress controller (AWS ALB, nginx, Traefik, Istio gateway, etc.) skip this step and map its DNS name to your customer-facing domain. Otherwise, install one:

```bash
# Example: nginx ingress deployed once per cluster
kubectl create namespace ingress-nginx
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx \\
  --namespace ingress-nginx
```

On managed clouds:

- **EKS** – prefer AWS Load Balancer Controller if you want native ALB + ACM certificates. Create an IngressClass named `alb` and update `values.yml` so `gateway.className` and `mappingGateway.className` use `alb`.
- **GKE / AKS** – use the provider’s ingress add-ons or nginx.
- **On-prem** – deploy nginx/Traefik and expose it via LoadBalancer/NodePort.

Configure DNS so `importer.customer.com` (or your chosen host) resolves to the ingress controller’s external IP / load balancer. For local testing you can still use `/etc/hosts` + `port-forward`, but production customers typically rely on managed DNS.

---

## 4. Deploy the importer suite

```bash
# From a workstation with kubeconfig pointing at the prod cluster
git clone https://github.com/getnuvo/importer-onpremise.git
cd importer-onpremise

# Optional but recommended: capture the current defaults for review
helm show values helm-chart/ingestro-importer > values.yaml

# Create your own override file (not tracked in git)
cp values.yaml values.develop.yaml
# ...edit values.develop.yaml with secrets, domains, replicas, etc...

# Install or upgrade into the target namespace (idempotent)
RELEASE_NAME=${RELEASE_NAME:-ingestro-importer}
NAMESPACE=${NAMESPACE:-ingestro-importer}

helm upgrade --install "$RELEASE_NAME" \\
  helm-chart/ingestro-importer \\
  --namespace "$NAMESPACE" \\
  --create-namespace \\
  --values values.develop.yaml
```

Because this uses `helm upgrade --install`, you can rerun the exact same command after editing your values file and Helm will either create the release (if it does not exist) or upgrade it in place—no manual cleanup required. To remove everything later: `helm uninstall "$RELEASE_NAME" -n "$NAMESPACE"`.

---

## 5. What the chart creates

| Component                                      | Description                                                      | Health endpoint in-cluster                                        |
| ---------------------------------------------- | ---------------------------------------------------------------- | ----------------------------------------------------------------- |
| importer Deployment + Service                  | Main SDK API (`/sdk/v1/...`)                                     | `http://<pod>:3000/sdk/v1/health`                                 |
| mapping Deployment + Service                   | Mapping API (`/sdk/mapping/...`)                                 | `http://<pod>:3001/health` (rewritten from `/sdk/mapping/health`) |
| aiService Deployment + Service                 | AI helper service (`/sdk/service/...`)                           | `http://<pod>:3002/sdk/service/health`                            |
| Mongo StatefulSet                              | Backing database with PVC                                        | `kubectl exec ... -- mongosh` for checks                          |
| Ingress `importer-ingestro-importer-gateway`   | Routes `/sdk/v1` → importer, `/sdk/service` → ai-service         | —                                                                 |
| Ingress `importer-ingestro-importer-mapping-*` | Routes `/sdk/mapping` → mapping                                  | —                                                                 |
| Image pull secret                              | Automatically created when `global.imageCredentials.create=true` | `/api/v1/namespaces/importer/secrets/<name>`                      |

---

## 6. Verification checklist

```bash
# Pods should all be Running/1/1
kubectl get pods -n "$NAMESPACE"

# Services and ingress definitions
kubectl get svc -n "$NAMESPACE"
kubectl get ingress -n "$NAMESPACE"
```

Port-forward any service for debugging:

```bash
# importer
kubectl port-forward svc/importer-ingestro-importer-importer 3000:3000 -n importer
# mapping
kubectl port-forward svc/importer-ingestro-importer-mapping 3001:3001 -n importer
# ai-service
kubectl port-forward svc/importer-ingestro-importer-aiservice 3002:3002 -n importer
```

Through the ingress (requires controller + hosts entry):

```bash
# Importer health
curl -H "Host: importer.customer.com" https://importer.customer.com/sdk/v1/health

# Mapping health
curl -H "Host: importer.customer.com" https://importer.customer.com/sdk/mapping/health

# AI service health
curl -H "Host: importer.customer.com" https://importer.customer.com/sdk/service/health
```

If you prefer Postman, set the request URL to `http://importer.local:8080/...` (or use `localhost` plus the `Host` header), and provide any auth headers/body your APIs expect.

---

## 7. Useful commands

```bash
# Dry-run render (generates rendered.yaml locally; not part of the repo)
helm template importer helm-chart/ingestro-importer \\
  --namespace "$NAMESPACE" \\
  --values values.develop.yaml \\
  > rendered.yaml

# Upgrade in place
helm upgrade "$RELEASE_NAME" helm-chart/ingestro-importer \\
 --namespace "$NAMESPACE" \\
  --values values.develop.yaml

# Remove everything
helm uninstall "$RELEASE_NAME" -n "$NAMESPACE"
```
