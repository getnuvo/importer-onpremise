# nuvo-onpremise

## Overview

The nuvo-onpremise repository provides scripts and configurations to set up LocalStack for testing with docker-compose.yaml and an install.sh script to install Docker and Docker Compose tools. Additionally, this guide includes steps to create services and routes via Kong API.

## Installation

To install Docker and Docker Compose, run the provided installation script:

```bash
./scripts/install.sh
```

This script:

- Installs Docker
- Installs Docker Compose
- Configures the system to allow running Docker without sudo
- Pulls nuvo images (requires appropriate permissions)

## Setting up LocalStack

LocalStack simulates AWS services locally. To start LocalStack using Docker Compose:

```bash
docker-compose up -d
```

This will spin up all services defined in docker-compose.yaml.

To check running containers:

```bash
docker ps
```

To stop the services:

```bash
docker-compose down
```

## Creating a Service and Route via Kong API

Kong API Gateway allows you to manage microservices efficiently. Below are steps to set up a service and route:

1. Add a New Service

For the **Importer Module** Service:

```bash
curl -i -X POST --url http://localhost:8001/services/ \
  --data 'name=importer-service' \
  --data 'url=http://importer-module:3000'
```

For the **Mapping Module** Service:

```bash
curl -i -X POST --url http://localhost:8001/services/ \
  --data 'name=mapping-service' \
  --data 'url=http://mapping-module:8000'
```

2. Add Routes to the Services

For the **Importer Module** Service:

```bash
curl -i -X POST --url http://localhost:8001/services/importer-service/routes \
  --data 'name=importer-route' \
  --data 'paths[]=/sdk/v1' \
  --data 'strip_path=false'
```

For the **Mapping Module** Service:

```bash
curl -i -X POST --url http://localhost:8001/services/mapping-service/routes \
  --data 'name=mapping-route' \
  --data 'paths[]=/sdk/mapping' \
  --data 'strip_path=true'
```

## Access Points

**Accessing Kong GUI**

You can access the Kong Admin GUI by visiting: http://localhost:8002

**APIs**

- Base Endpoint: http://localhost:8000
- Health Check - Importer Module: `/sdk/v1/auth/health`
- Health Check - Mapping Module: `/sdk/mapping/health`

## Helm Chart Setup (Coming Soon)

We are working on a Helm chart setup for easier deployment. Stay tuned for updates!

## Conclusion

This repository helps you set up a local development environment using LocalStack, Docker, and Kong API Gateway. Follow the steps above to install necessary tools, start LocalStack, and configure Kong for service routing.
