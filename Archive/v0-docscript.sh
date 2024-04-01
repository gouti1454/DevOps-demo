#!/bin/bash

#version3
sudo docker volume prune
sudo docker container prune
sudo rmdir prometheus.yml
sudo rm Dockerfile
sudo rm docker-compose.yml

sudo apt update
sudo apt upgrade -y

sudo apt install -y ca-certificates curl gnupg lsb-release
sudo mkdir -p /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo echo  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update

sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
#checking docker status
sudo docker run hello-world

sudo apt install docker -y
sudo systemctl restart docker && sudo systemctl enable docker

sudo curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

# Set the image name and version
IMAGE_NAME="my-app-02"
IMAGE_VERSION="2.0"


# Create a new Dockerfile
cat << EOF > Dockerfile
FROM busybox:latest
ENV PORT=8000
LABEL maintainer="Chris <c@crccheck.com>"


# EXPOSE $PORT

HEALTHCHECK CMD nc -z localhost $PORT

# Create a basic webserver and run it until the container is stopped
CMD echo "httpd started" && trap "exit 0;" TERM INT; httpd -v -p $PORT -h /www -f & wait
EOF


# Build the Docker image
docker build -t ${IMAGE_NAME}:${IMAGE_VERSION} .

# Run the Docker image

cat <<EOF >/home/portdemo/demodocker/docker-compose.yml
version: '3.9'
services:
  cadvisor:
      image: gcr.io/cadvisor/cadvisor:latest
      hostname: cadvisor
      volumes:
        - "/:/rootfs:ro"
        - "/var/run:/var/run:ro"
        - "/sys:/sys:ro"
        - "/var/lib/docker/:/var/lib/docker:ro"
        - "/dev/disk/:/dev/disk:ro"
      ports:
        - "8080:8080"

  prometheus:
    image: prom/prometheus
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus-scrape-config.yaml
    ports:
      - "9090:9090"

  grafana:
    image: grafana/grafana
    user: "$UID:$GID"
    volumes:
      - ./data/grafana:/var/lib/grafana
    ports:
      - "3000:3000"

  Dockerfile:
    image: crccheck/hello-world
    deploy:
      mode: replicated
      replicas: 3
    ports:
      - 8000

EOF
chown portdemo:portdemo /home/portdemo/demodocker/docker-compose.yml
sudo /usr/local/bin/docker-compose -f  /home/portdemo/demodocker/docker-compose.yml up -d
#sudo docker-compose up -d