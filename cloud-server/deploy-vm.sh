#!/bin/bash
set -e

echo "=== Cloud Storage Deployment ==="

# Install Docker
curl -fsSL https://get.docker.com | bash
sudo usermod -aG docker $USER

# Create project directory
mkdir -p ~/cloud && cd ~/cloud

# Docker Compose file
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  db:
    image: postgres:16-alpine
    restart: unless-stopped
    volumes:
      - ./postgres:/var/lib/postgresql/data
    environment:
      POSTGRES_DB: nextcloud
      POSTGRES_USER: nextcloud
      POSTGRES_PASSWORD: changeme_password
    networks:
      - nextcloud-net

  redis:
    image: redis:7-alpine
    restart: unless-stopped
    networks:
      - nextcloud-net

  app:
    image: nextcloud:30-apache
    restart: unless-stopped
    ports:
      - "80:80"
    depends_on:
      - db
      - redis
    volumes:
      - ./nextcloud:/var/www/html
      - ./config:/var/www/html/config
      - ./data:/var/www/html/data
    environment:
      POSTGRES_HOST: db
      POSTGRES_DB: nextcloud
      POSTGRES_USER: nextcloud
      POSTGRES_PASSWORD: changeme_password
      REDIS_HOST: redis
      NEXTCLOUD_ADMIN_USER: admin
      NEXTCLOUD_ADMIN_PASSWORD: admin123
      NEXTCLOUD_TRUSTED_DOMAINS: localhost 127.0.0.1
    networks:
      - nextcloud-net

networks:
  nextcloud-net:
    driver: bridge
EOF

# Create directories
mkdir -p postgres config data

# Start
sudo docker compose up -d

echo "=== Done! Nextcloud is running on port 80 ==="
echo "Login: admin / admin123"
echo "Access it at your VM's public IP address"
