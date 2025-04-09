<!-- markdownlint-disable -->

<div align="center">
  <a href="https://getnuvo.com/" target="_blank" rel="noopener noreferrer">
    <img width="150" src="https://general-upload.getnuvo.com/nuvo_logo_with_text.svg" alt="nuvo logo">
  </a>
  <p><strong>Fast, secure, and scalable data imports.</strong></p>
</div>

<h1 align="center">Deploying the nuvo Importer Backend On-Premise</h1>

<p>
  Combine this backend setup with our <a href="https://getnuvo.com/importer">nuvo Importer UI libraries</a> to deliver a seamless and intuitive import experience directly within your platform.
</p>



## 🧩 Compatibility

This backend is compatible with the following frontend packages:

- React: [`@getnuvo/importer-react`](https://www.npmjs.com/package/@getnuvo/importer-react)
- Angular: [`@getnuvo/importer-angular`](https://www.npmjs.com/package/@getnuvo/importer-angular)
- Vue: [`@getnuvo/importer-vue`](https://www.npmjs.com/package/@getnuvo/importer-vue)
- Vanilla JS: [`@getnuvo/importer-vanilla-js`](https://www.npmjs.com/package/@getnuvo/importer-vanilla-js)


## 🚀 Getting Started

Before you begin, make sure:

- You’ve signed up at [nuvo](https://dashboard.getnuvo.com).
- You have your **License Key** ready for on-premise deployment.


## ⚙️ Installation

After cloning this repository, run the following script to install Docker and Docker Compose, and to prepare your system:

```bash
./scripts/install.sh
```

This script will:
- Install Docker & Docker Compose
- Allow Docker to run without sudo
- Pull the required nuvo backend images (requires proper access)

## 🎬 Start Docker Service

```bash
docker-compose up -d
```

## 🔁 Configure Routing

Once the Docker services are running, execute the route configuration script:

```bash
./scripts/configure_routes.sh
```

> ℹ️ Ensure Docker Compose is up and running before executing this script — it requires access to the Kong Admin API.

This step sets up all required services and routes for:
- importer-module
- mapping-module

Routing is handled via the Kong Admin API.


## 🔄 Updating the Services
To refresh your deployment with the latest version and clean up unused containers/images, run:
```bsh
./scripts/update_nuvo.sh
```

This script will:

- Pull the latest backend images
- Recreate containers with Docker Compose
- Prune unused Docker resources
- Show the status of currently running containers


## 🔌 Access Points
Kong Admin GUI:
http://localhost:8002

API Endpoints
Base URL: http://localhost:8000
- Importer Module Health Check: http://localhost:8000/sdk/v1/health
- Mapping Module Health Check: http://localhost:8000/sdk/mapping/health

## 📚 Documentation & Support
For full deployment guides, production best practices, or technical documentation, please reach out to our team at sales@getnuvo.com.