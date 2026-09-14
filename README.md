<!-- markdownlint-disable -->

<p align="center">
  <a href="https://ingestro.com/" rel="noopener" target="_blank"><img width="150" src="https://s3.eu-central-1.amazonaws.com/general-upload.ingestro.com/ingestro_logo_darkblue.svg" alt="Ingestro logo"></a>
</p>

<h1 align="center">Ingestro Importer Self Host Guide</h1>

<p>
  Combine this backend setup with our <a href="https://docs.ingestro.com/sdk/start/">Ingestro Importer UI libraries</a> to deliver a seamless and intuitive import experience directly within your platform.
</p>

## Compatibility

This backend is compatible with the following frontend packages:

- React: [`@getnuvo/importer-react`](https://www.npmjs.com/package/@getnuvo/importer-react)
- Angular: [`@getnuvo/importer-angular`](https://www.npmjs.com/package/@getnuvo/importer-angular)
- Vue: [`@getnuvo/importer-vue`](https://www.npmjs.com/package/@getnuvo/importer-vue)
- Vanilla JS: [`@getnuvo/importer-vanilla-js`](https://www.npmjs.com/package/@getnuvo/importer-vanilla-js)

## Getting Started

Before you begin, make sure:

- You’ve signed up at [ingestro](https://dashboard.ingestro.com).
- You have your **License Key** ready for on-premise deployment.

## Installation

### Option A (recommended): Helm

A new production-ready Helm chart (see `helm-chart/ingestro-importer`) bundles MongoDB, importer, mapping, and AI services with ingress routing, probes, autoscaling hooks, and secret management—similar to the Qovery self-managed chart.

```bash
cd ./

# Inspect defaults and craft an override file for secrets and env vars
helm show values helm-chart/ingestro-importer > values.example.yaml
cp values.example.yaml values.production.yaml

# Edit values.production.yaml (set license keys, AWS/Azure creds, TLS hosts, etc.)
helm install importer \
  helm-chart/ingestro-importer \
  --namespace importer \
  --create-namespace \
  --values values.production.yaml
```

Upgrade with:

```bash
helm upgrade importer \
  helm-chart/ingestro-importer \
  --namespace importer \
  --values values.production.yaml
```

Use `kubectl get pods -n importer` and `kubectl get ingress -n importer` to confirm the rollout, then hit `/sdk/v1/health`, `/sdk/mapping/health`, and `/sdk/service/health` through the ingress endpoint.

### Option B: Docker Compose

After cloning this repository, create the required env files from the templates:

- `cp example.importer-module.docker.env importer-module.docker.env`
- `cp example.mapping-module.docker.env mapping-module.docker.env`
- `cp example.service-module.docker.env service-module.docker.env`

Run the following script to install Docker and Docker Compose, and to prepare your system:

```bash
./scripts/install.sh
```

This script will:

- Install Docker & Docker Compose
- Allow Docker to run without sudo
- Pull the required Ingestro backend images (requires proper access)

#### Start Docker Service

```bash
docker-compose up -d
```

#### Configure Routing

Once the Docker services are running, execute the route configuration script:

```bash
./scripts/configure.sh
```

> NOTE: Ensure Docker Compose is up and running before executing this script — it requires access to the Kong Admin API.

This step sets up all required services and routes for:

- importer-module
- mapping-module
- ai-service-module

Routing is handled via the Kong Admin API.

#### Updating the Services

To refresh your deployment with the latest version and clean up unused containers/images, run:

```bash
./scripts/update.sh
```

This script will:

- Pull the latest backend images
- Recreate containers with Docker Compose
- Prune unused Docker resources
- Show the status of currently running containers

## Option Mapping and S3 storage

Not every matching feature needs object storage. You can deploy and run the backend without an S3 bucket — configure one only if your import template uses server-side option mapping.

### What works without an S3 bucket

| Feature | Notes |
| ------- | ----- |
| **Column matching** (server-side) | Sheet headers and target columns are sent directly to the mapping module — no bucket needed. |
| **Option matching** (browser-side) | The default for dropdown/category columns. Runs in the user's browser. |

### What requires an S3 bucket

| Feature | Notes |
| ------- | ----- |
| **Option matching** (server-side) | Used when a column sets `optionMappingConfiguration.processingMode: 'node'` in your target data model. The importer uploads sheet data to S3; the mapping module reads it via a presigned URL. |

### Configure S3 credentials

Set these on the **importer module** (Helm secrets or Docker Compose env file):

| Variable | Purpose |
| -------- | ------- |
| `IMPORTER_AWS_S3_BUCKET` | Bucket for temporary sheet uploads during server-side option matching |
| `IMPORTER_AWS_REGION` | AWS region of the bucket |
| `IMPORTER_AWS_ACCESS_KEY` | Access key (omit when using an IAM role attached to the pod or host) |
| `IMPORTER_AWS_SECRET_KEY` | Secret key (omit when using an IAM role) |

**Helm:** set the values under `importer.secrets` in your override file — see [values.yaml](helm-chart/ingestro-importer/values.yaml) for defaults and the [Helm chart README](helm-chart/ingestro-importer/README.md#option-mapping-and-s3-bucket-importersecrets) for S3 and secret-handling options (inline, existing Secret, or ExternalSecret).

**Docker Compose:** after `docker-compose up -d`, run [`scripts/configure.sh`](scripts/configure.sh). When prompted, choose to set up your AWS S3 bucket; the script writes the credentials into `importer-module.docker.env` (template: [`example.importer-module.docker.env`](example.importer-module.docker.env)).

> **Deploying without a bucket?** Column matching and browser-side option matching work as-is. If your target data model uses server-side option matching, either configure the bucket above or set `optionMappingConfiguration.processingMode: 'browser'` on those columns.

## Access Points

API Endpoints
Base URL: http://localhost:8000 | http://localhost:8080

- Importer Module Health Check: http://localhost:8000/sdk/v1/health
- Mapping Module Health Check: http://localhost:8000/sdk/mapping/health
- AI Service Module Health Check: http://localhost:8000/sdk/service/health

## Documentation & Support

For full deployment guides, production best practices, or technical documentation, please reach out to our team at support@ingestro.com.
