#!/bin/bash

set -e

install_docker_ubuntu() {
    echo "Installing Docker on Ubuntu..."

    sudo apt update
    sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
    sudo apt update
    sudo apt install -y docker-ce

    sudo systemctl enable docker
    sudo systemctl start docker
    sudo systemctl status docker --no-pager

    echo "Docker installed successfully!"
}

install_docker_compose_ubuntu() {
    echo "Installing Docker Compose on Ubuntu..."

    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose

    docker-compose --version

    echo "Docker Compose installed successfully!"
}

install_docker_macos() {
    echo "Installing Docker on macOS using Homebrew..."

    brew install docker

    echo "Docker installed successfully!"
}

install_docker_compose_macos() {
    echo "Installing Docker Compose on macOS using Homebrew..."

    brew install docker-compose

    echo "Docker Compose installed successfully!"
}

prepare_nuvo_images() {
    echo "Preparing nuvo images..."

    docker pull getnuvo/importer:latest
    docker pull getnuvo/mapping-module:latest

    echo "nuvo images prepared successfully!"
}

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if ! command -v docker &> /dev/null; then
        install_docker_ubuntu
    else
        echo "Docker is already installed."
    fi
    if ! command -v docker-compose &> /dev/null; then
        install_docker_compose_ubuntu

        sudo usermod -aG docker $USER
        sudo chmod 666 /var/run/docker.sock
        sudo systemctl restart docker
        newgrp docker
    else
        echo "Docker Compose is already installed."
    fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
    if ! command -v brew &> /dev/null; then
        echo "Homebrew is not installed. Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi

    if ! command -v docker &> /dev/null; then
        install_docker_macos
    else
        echo "Docker CLI is already installed."
    fi
    if ! command -v docker-compose &> /dev/null; then
        install_docker_compose_macos
    else
        echo "Docker Compose is already installed."
    fi
else
    echo "Unsupported OS"
    exit 1
fi

prepare_nuvo_images
