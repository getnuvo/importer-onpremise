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

## Setting up LocalStack via Docker Compose

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

## Setting up LocalStack via Helm Chart

This guide will help you set up and deploy services locally using Helm charts on Kubernetes with Minikube. It simplifies the process of testing and managing your services.

### Prerequisites

Ensure the following tools are installed and configured:

- Docker
- Kubernetes (v1.31.4 or later)
- Minikube
- Helm

### Setup Process

1. Start Minikube

First, start the Minikube server to set up the Kubernetes cluster:

```bash
minikube start
```

2. Enable NGINX Ingress Addon

Enable the NGINX ingress addon in Minikube. This will create a new namespace ingress-nginx and deploy the NGINX ingress controller.

```bash
minikube addons enable ingress
```

3. Login to Docker Registry

Before installing services, log in to the Docker registry. Replace `{username}` and `{password}` with your Docker Hub credentials.

```bash
kubectl create secret docker-registry -n ingress-nginx my-dockerhub-secret \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username={username} \
  --docker-password={password} \
  --docker-email=-
```

4. Install the Services

1. Install nginx-ingress

```bash
helm install nginx-ingress ./helm-chart/nginx-ingress-chart
```

2. Install Importer and Mapping Services

After the ingress controller is set up, you can install the services:

```bash
helm install importer ./helm-chart/importer-chart -n ingress-nginx

helm install mapping ./helm-chart/mapping-chart -n ingress-nginx
```

5. Check the Service Status

After installing, verify that all the pods are running. You should see the following services in `Running` status:

```bash
 kubectl get pod -n ingress-nginx
```

The expected services are:

1. `ingress-nginx-controller`
2. `importer-module`
3. `mapping-module`
4. `mongo`

If any pod fails to start, you can troubleshoot using:

```bash
kubectl describe pod <pod_name> -n ingress-nginx
```

6. Port Forwarding

To access the services locally, you have two options:

**Option 1: Using** kubectl port-forward

You can forward the port to access the services locally. You can change 8000 to any port you prefer:

```bash
kubectl port-forward --namespace=ingress-nginx service/ingress-nginx-controller 8000:80
```

Once the port is forwarded, you can access the services via http://localhost:8000.

**Option 2: Using** minikube tunnel (Recommended)

Alternatively, you can use minikube tunnel to create routes to your services in the Minikube cluster. This method doesn't require manually forwarding individual ports:

1. Start the minikube tunnel:

```bash
minikube tunnel
```

2. After running the tunnel, your services will be accessible through localhost without the need to specify ports for each service.

The nginx-ingress-controller will be available at http://localhost:80.
You can access your services through their defined paths (e.g., http://localhost/sdk/v1/...).

## Conclusion

This repository provides comprehensive instructions for setting up a local development environment using both Docker Compose and Kubernetes. For services running with Docker Compose, Kong is used as the API Gateway to manage and route traffic. For Kubernetes-based deployments, Helm charts and the NGINX Ingress Controller are used for service management and routing.