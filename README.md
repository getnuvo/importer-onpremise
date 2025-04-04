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
- Health Check - Importer Module: `/sdk/v1/management/health`
- Health Check - Mapping Module: `/sdk/mapping/health`

## Helm Chart Setup

We are setting up a Helm chart to simplify local deployment and testing. This setup allows you to deploy services efficiently using Kubernetes and Helm.

### Develop purpose

#### Environment

- Docker
- Kubernates v1.31.4
- Minikube
- Helm

#### Preparation

We assume that you've already run `Docker`, `Kubernates with docker driven` then do follow these step.

- Start minikube server.

```bash
minikube start
```

- Enable addons to using Nginx.

```bash
minikube addons enable ingress
```

The command will create new namespace call `ingress-nginx` and add Nginx service in.

- Before install the service we need to login to `Docker registry hub` for `Kubernates`.

```bash
# using dockerhub credential that generated from Nuvo
kubectl create secret docker-registry -n ingress-nginx my-dockerhub-secret \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username={username} \
  --docker-password={password} \
  --docker-email=-
```

- Install services

Before you run the `mapping-module` please recheck your environment keys here `mapping-chart/mapping-module-docker-env-configmap.yaml`.

```bash
helm install importer ./helm-chart/importer-chart -n ingress-nginx

helm install mapping ./helm-chart/mapping-chart -n ingress-nginx
```

- Check service status

```bash
 kubectl get pod -n ingress-nginx
```

And see the list these 4 should in `running` status.

```js
ingress - nginx - controller;
importer - module;
mapping;
mongo;
```

If there have any image has failed to run you can use the command to debug it.

```bash
kubectl describe pod {pod_name eg.importer-module-xxxx} -n ingress-nginx
```

- Apply ingress file by add route rules.

```js
kubectl apply -f ./helm-chart/ingress.yaml -n ingress-nginx
```

- Fowarding port (you can change running port 8080 to any you want).

```bash
kubectl port-forward --namespace=ingress-nginx service/ingress-nginx-controller 8080:80
```

- Finally you service is running at `http://localhost:8080`.

## Conclusion

This repository helps you set up a local development environment using LocalStack, Docker, and Kong API Gateway. Follow the steps above to install necessary tools, start LocalStack, and configure Kong for service routing.
