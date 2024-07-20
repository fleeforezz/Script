#!/bin/bash

# Check update 
sudo apt update && sudo apt upgrade -y

# Install docker 
sudo apt install docker.io -y

# Install docker compose
sudo apt install curl -y
sudo curl -L "https://github.com/docker/compose/releases/download/1.29.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Check version
docker-compose -v
docker -v