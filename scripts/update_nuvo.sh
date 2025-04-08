#!/bin/bash

docker-compose down

docker-compose pull

docker-compose up --build -d

docker system prune -f

docker-compose ls