# DDALAB Setup

This repository contains the configuration files needed to set up and run the DDALAB (Delay Differential Analysis Laboratory) application using Docker and Traefik. Instead of containing the actual application code, this repository provides the necessary infrastructure configuration to easily deploy your own instance of DDALAB.

## Overview

The setup includes:

- Traefik as a reverse proxy with SSL support
- Docker Compose configuration for service orchestration
- Prometheus monitoring setup
- Automatic SSL certificate management
- Secure configuration templates

## Prerequisites

### Installing Docker

1. **For macOS**:

   - Download [Docker Desktop for Mac](https://www.docker.com/products/docker-desktop)
   - Double-click the downloaded .dmg file and drag Docker to Applications
   - Open Docker from Applications folder

2. **For Windows**:

   - Download [Docker Desktop for Windows](https://www.docker.com/products/docker-desktop)
   - Run the installer and follow the prompts
   - Start Docker Desktop from the Start menu

3. **For Linux (Ubuntu/Debian)**:

   ```bash
   sudo apt update
   sudo apt install docker.io docker-compose
   sudo systemctl enable --now docker
   sudo usermod -aG docker $USER
   # Log out and back in for group changes to take effect
   ```

Verify installation:

```bash
docker --version
docker compose --version
```

## Repository Structure

```
├── docker-compose.yml    # Main service orchestration configuration
├── traefik.yml          # Traefik reverse proxy configuration
├── prometheus.yml       # Prometheus monitoring configuration
├── dynamic/            # Dynamic Traefik configuration
│   └── routers.yml     # Service routing rules
├── certs/              # Directory for SSL certificates
├── traefik-logs/       # Traefik access logs
├── acme.json           # Let's Encrypt certificate storage
├── up.sh              # Startup script
└── cleanup.sh         # Cleanup script
```

## Getting Started

1. **Clone this Repository**:

   ```bash
   git clone https://github.com/sdraeger/DDALAB-setup.git
   cd DDALAB-setup
   ```

2. **Set up SSL Certificates**:

   Create self-signed certificates for development:

   ```bash
   mkdir -p certs
   cd certs
   openssl genrsa -out server.key 2048
   openssl req -new -key server.key -out server.csr
   openssl x509 -req -days 365 -in server.csr -signkey server.key -out server.crt
   cd ..
   ```

3. **Configure Traefik**:

   - Review and adjust `traefik.yml` for your needs
   - Check routing rules in `dynamic/routers.yml`
   - Set appropriate permissions for acme.json:

     ```bash
     touch acme.json
     chmod 600 acme.json
     ```

4. **Start the Services**:

   Using the provided script:

   ```bash
   ./up.sh
   ```

   Or manually:

   ```bash
   docker compose up
   ```

5. **Clean up**:

   When needed, use the cleanup script:

   ```bash
   ./cleanup.sh
   ```

## Configuration Files

### `docker-compose.yml`

Contains the service definitions and their configurations. Review and adjust the following:

- Port mappings
- Volume mounts
- Environment variables
- Service dependencies

### Environment Variables (`.env`)

The `.env` file contains important configuration settings. Key variables include:

#### `DDALAB_ALLOWED_DIRS`

This variable controls directory access and mapping between the host system and containers. It's crucial for security and proper file system access.

Format: `HOST_PATH:CONTAINER_PATH:PERMISSION[,HOST_PATH2:CONTAINER_PATH2:PERMISSION2,...]`

Components:

- `HOST_PATH`: Absolute path on your host machine
- `CONTAINER_PATH`: Corresponding path inside the container
- `PERMISSION`: Access level (`ro` for read-only, `rw` for read-write)

Example configurations:

```env
# Single directory with read-only access
DDALAB_ALLOWED_DIRS=/Users/your-name/Desktop:/app/data/Desktop:ro

# Multiple directories with different permissions
DDALAB_ALLOWED_DIRS=/Users/your-name/Desktop:/app/data/Desktop:ro:/Users/your-name/uploads:/app/uploads:rw
```

Security considerations:

- Always use absolute paths
- Carefully consider which directories need read-write access
- Restrict access to only necessary directories
- Regularly audit directory permissions

### `traefik.yml`

Main Traefik configuration file. Key areas to review:

- Entry points configuration
- SSL settings
- Dashboard access
- Log levels

### `dynamic/routers.yml`

Contains the routing rules for your services. Adjust:

- Service endpoints
- Middleware chains
- TLS options

## Monitoring

The setup includes Prometheus for monitoring. Access the following endpoints:

- Traefik Dashboard: `https://localhost:8080`
- Prometheus: `http://localhost:9090`

## Troubleshooting

1. **Certificate Issues**:
   - Ensure `certs/` directory contains valid certificates
   - Check `acme.json` permissions (should be 600)
   - Verify Traefik SSL configuration in `traefik.yml`

2. **Network Issues**:
   - Check if ports are already in use
   - Verify Docker network creation
   - Review service logs: `docker compose logs [service_name]`

3. **Permission Issues**:
   - Ensure proper file permissions on all configuration files
   - Verify Docker daemon access
   - Check volume mount permissions

## Security Notes

1. **Dashboard Security**:
   - Change default credentials in `traefik.yml`
   - Use strong passwords
   - Consider restricting dashboard access to specific IPs

2. **SSL Configuration**:
   - Keep certificates secure
   - Regularly update certificates
   - Use production-grade certificates in production

## Support

For issues specific to this setup configuration:

- Open an issue in this repository

For DDALAB application issues:

- Visit the main DDALAB repository
