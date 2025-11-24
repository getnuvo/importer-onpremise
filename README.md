<!-- markdownlint-disable -->

<p align="center">
  <a href="https://ingestro.com/" rel="noopener" target="_blank"><img width="150" src="https://s3.eu-central-1.amazonaws.com/general-upload.ingestro.com/ingestro_logo_darkblue.svg" alt="Ingestro logo"></a>
</p>

<h1 align="center">Ingestro Importer Self Host Guide</h1>

<p>
  Combine this backend setup with our <a href="https://ingestro.com/importer">Ingestro Importer UI libraries</a> to deliver a seamless and intuitive import experience directly within your platform.
</p>

## 🧩 Compatibility

This backend is compatible with the following frontend packages:

- React: [`@getnuvo/importer-react`](https://www.npmjs.com/package/@getnuvo/importer-react)
- Angular: [`@getnuvo/importer-angular`](https://www.npmjs.com/package/@getnuvo/importer-angular)
- Vue: [`@getnuvo/importer-vue`](https://www.npmjs.com/package/@getnuvo/importer-vue)
- Vanilla JS: [`@getnuvo/importer-vanilla-js`](https://www.npmjs.com/package/@getnuvo/importer-vanilla-js)

## 🚀 Getting Started

Before you begin, make sure:

- You’ve signed up at [ingestro](https://dashboard.ingestro.com).
- You have your **License Key** ready for on-premise deployment.

## ⚙️ Installation

### Option A (recommended): Helm

A new production-ready Helm chart (see `helm-chart/ingestro-importer`) bundles MongoDB, importer, mapping, and AI services with ingress routing, probes, autoscaling hooks, and secret management—similar to the Qovery self-managed chart.

```bash
cd /Users/yousafishaq/Documents/GitHub/importer-onpremise

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

#### 🎬 Start Docker Service

```bash
docker-compose up -d
```

#### 🔁 Configure Routing

Once the Docker services are running, execute the route configuration script:

```bash
./scripts/configure.sh
```

> ℹ️ Ensure Docker Compose is up and running before executing this script — it requires access to the Kong Admin API.

This step sets up all required services and routes for:

- importer-module
- mapping-module
- ai-service-module

Routing is handled via the Kong Admin API.

#### 🔄 Updating the Services

To refresh your deployment with the latest version and clean up unused containers/images, run:

```bash
./scripts/update.sh
```

This script will:

- Pull the latest backend images
- Recreate containers with Docker Compose
- Prune unused Docker resources
- Show the status of currently running containers

## 🔌 Access Points

API Endpoints
Base URL: http://localhost:8000 | http://localhost:8080

- Importer Module Health Check: http://localhost:8000/sdk/v1/health
- Mapping Module Health Check: http://localhost:8000/sdk/mapping/health
- AI Service Module Health Check: http://localhost:8000/sdk/service/health

## 📚 Documentation & Support

For full deployment guides, production best practices, or technical documentation, please reach out to our team at sales@ingestro.com.
