#!/bin/bash

set -e

# Styling
GREEN='\033[1;32m'
RED='\033[1;31m'
BOLD='\033[1m'
NC='\033[0m'

install_docker_ubuntu() {
    echo -e "${BOLD}Installing Docker on Ubuntu...${NC}"

    sudo apt update
    sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
    sudo apt update
    sudo apt install -y docker-ce

    sudo systemctl enable docker
    sudo systemctl start docker
    sudo systemctl status docker --no-pager

    echo -e "${GREEN}Docker installed successfully!${NC}"
}

install_docker_compose_ubuntu() {
    echo -e "${BOLD}Installing Docker Compose on Ubuntu...${NC}"

    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose

    docker-compose --version

    echo -e "${GREEN}Docker Compose installed successfully!${NC}"
}

install_docker_macos() {
    echo -e "${BOLD}Installing Docker on macOS using Homebrew...${NC}"
    brew install docker
    echo -e "${GREEN}Docker installed successfully!${NC}"
}

install_docker_compose_macos() {
    echo -e "${BOLD}Installing Docker Compose on macOS using Homebrew...${NC}"
    brew install docker-compose
    echo -e "${GREEN}Docker Compose installed successfully!${NC}"
}

prepare_nuvo_images() {
    echo -e "${BOLD}Checking Docker Hub authentication status...${NC}"

    # Check if user is already logged in to Docker Hub as getnuvo
    if grep -q '"auths":' ~/.docker/config.json 2>/dev/null && \
       grep -q '"https://index.docker.io/v1/"' ~/.docker/config.json 2>/dev/null; then
        echo -e "${GREEN}Already logged into Docker Hub. Skipping login step.${NC}"
    else
        echo -e "${BOLD}Not logged in. Docker Hub authentication required.${NC}"
        read -s -p "Enter your Docker Hub access token for user 'getnuvo': " docker_token
        echo ""

        echo -e "${BOLD}Logging in to Docker Hub...${NC}"
        echo "$docker_token" | docker login -u getnuvo --password-stdin
        echo -e "${GREEN}Logged in successfully.${NC}"
    fi

    echo -e "${BOLD}Pulling nuvo images...${NC}"
    docker pull getnuvo/importer:latest
    docker pull getnuvo/mapping:latest

    echo -e "${GREEN}Nuvo images pulled successfully!${NC}"
}


############################################
# Docker installation based on OS
############################################

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if ! command -v docker &> /dev/null; then
        install_docker_ubuntu
    else
        echo -e "${GREEN}Docker is already installed.${NC}"
    fi

    if ! command -v docker-compose &> /dev/null; then
        install_docker_compose_ubuntu

        sudo usermod -aG docker "$USER"
        sudo chmod 666 /var/run/docker.sock
        sudo systemctl restart docker
        newgrp docker
    else
        echo -e "${GREEN}Docker Compose is already installed.${NC}"
    fi

elif [[ "$OSTYPE" == "darwin"* ]]; then
    if ! command -v brew &> /dev/null; then
        echo -e "${RED}Homebrew is not installed. Installing Homebrew...${NC}"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi

    if ! command -v docker &> /dev/null; then
        install_docker_macos
    else
        echo -e "${GREEN}Docker CLI is already installed.${NC}"
    fi

    if ! command -v docker-compose &> /dev/null; then
        install_docker_compose_macos
    else
        echo -e "${GREEN}Docker Compose is already installed.${NC}"
    fi
else
    echo -e "${RED}Unsupported OS. Exiting.${NC}"
    exit 1
fi

prepare_nuvo_images
