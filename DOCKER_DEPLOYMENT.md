# DDALAB Docker Deployment Guide

DDALAB is now available as Docker containers, making deployment much easier and more consistent across different environments. This guide will help you deploy DDALAB using Docker with minimal setup requirements.

## 🚀 Quick Start

### Prerequisites

- **Docker** installed and running
- At least **4GB RAM** available
- **10GB free disk space** for data storage

### Option 1: Automated Deployment Script

The easiest way to deploy DDALAB is using our automated script:

```bash
# Download and run the deployment script
curl -fsSL https://raw.githubusercontent.com/your-repo/DDALAB/main/deploy-ddalab.sh | bash

# Or run with a custom directory
./deploy-ddalab.sh /path/to/your/ddalab-installation
```

### Option 2: Manual Deployment

1. **Create deployment directory:**

   ```bash
   mkdir ddalab && cd ddalab
   ```

2. **Copy configuration files:**

   ```bash
   # Copy the main docker-compose.yml
   cp ../docker-compose.yml .

   # Copy traefik configuration
   cp ../traefik.yml .
   mkdir -p dynamic
   cp ../dynamic/routers.yml dynamic/
   ```

3. **Create environment file:**

   ```bash
   # Create .env file with Docker Hub images
   cat > .env << 'EOF'
   # Use Docker Hub images instead of building locally
   DDALAB_WEB_IMAGE=ddalab/web:latest
   DDALAB_API_IMAGE=ddalab/api:latest

   # Database Configuration
   DDALAB_DB_USER=ddalab
   DDALAB_DB_PASSWORD=ddalab_password
   DDALAB_DB_NAME=ddalab

   # MinIO Configuration
   MINIO_ROOT_USER=ddalab
   MINIO_ROOT_PASSWORD=ddalab_password

   # Web Application Port
   WEB_PORT=3000

   # Data Directory
   DDALAB_DATA_DIR=./data

   # Traefik Configuration
   TRAEFIK_ACME_EMAIL=admin@ddalab.local

   # Allowed Directories for API access
   DDALAB_ALLOWED_DIRS=./data:/app/data:rw
   EOF
   ```

4. **Create required directories:**

   ```bash
   mkdir -p data certs traefik-logs
   echo "{}" > acme.json
   ```

5. **Start services:**
   ```bash
   docker-compose up -d
   ```

## 📋 Service Information

Once deployed, DDALAB provides the following services:

| Service           | URL                    | Description             |
| ----------------- | ---------------------- | ----------------------- |
| **Web Interface** | http://localhost:3000  | Main DDALAB application |
| **API Server**    | http://localhost:8001  | DDALAB API endpoints    |
| **MinIO Console** | http://localhost:9001  | File storage management |
| **PostgreSQL**    | localhost:5432         | Database                |
| **Redis**         | localhost:6379         | Cache and sessions      |
| **Grafana**       | http://localhost:3005  | Monitoring dashboard    |
| **Prometheus**    | http://localhost:9090  | Metrics collection      |
| **Jaeger UI**     | http://localhost:16686 | Distributed tracing     |

## 🔧 Management Commands

### View Logs

```bash
cd ddalab
docker-compose logs -f
```

### Stop Services

```bash
cd ddalab
docker-compose down
```

### Restart Services

```bash
cd ddalab
docker-compose restart
```

### Update to Latest Version

```bash
cd ddalab
docker-compose pull
docker-compose up -d
```

### Backup Data

```bash
cd ddalab
docker-compose exec postgres pg_dump -U ddalab ddalab > backup.sql
```

### Restore Data

```bash
cd ddalab
docker-compose exec -T postgres psql -U ddalab ddalab < backup.sql
```

## ⚙️ Configuration

### Environment Variables

Edit the `.env` file to customize your deployment:

```bash
# Use Docker Hub images instead of building locally
DDALAB_WEB_IMAGE=ddalab/web:latest
DDALAB_API_IMAGE=ddalab/api:latest

# Database Configuration
DDALAB_DB_USER=ddalab
DDALAB_DB_PASSWORD=ddalab_password
DDALAB_DB_NAME=ddalab

# MinIO Configuration
MINIO_ROOT_USER=ddalab
MINIO_ROOT_PASSWORD=ddalab_password

# Web Application Port
WEB_PORT=3000

# Data Directory
DDALAB_DATA_DIR=./data

# Session Configuration
SESSION_EXPIRATION=10080

# Traefik Configuration
TRAEFIK_ACME_EMAIL=admin@ddalab.local
TRAEFIK_PASSWORD_HASH=

# Cache Configuration
DDALAB_PLOT_CACHE_TTL=3600

# Allowed Directories for API access
DDALAB_ALLOWED_DIRS=./data:/app/data:rw

# Grafana Configuration (optional)
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=admin
```

### Data Directory

The `data` directory is where your EDF files will be stored. You can mount external directories:

```yaml
# In docker-compose.yml
volumes:
  - /path/to/your/edf/files:/app/data:ro
```

### SSL Configuration

For production deployments, configure SSL certificates:

1. **Update Traefik configuration:**

   ```yaml
   # In traefik.yml
   certificatesResolvers:
     letsencrypt:
       acme:
         email: your-email@domain.com
   ```

2. **Update router rules:**
   ```yaml
   # In dynamic/routers.yml
   rule: "Host(`your-domain.com`)"
   ```

## 🔒 Security Considerations

### Default Credentials

⚠️ **Important:** Change default passwords for production use:

- **Database:** ddalab / ddalab_password
- **MinIO:** ddalab / ddalab_password
- **Grafana:** admin / admin

### Network Security

- Services are exposed on localhost by default
- For external access, configure proper firewall rules
- Use reverse proxy (Traefik) for SSL termination
- Consider using Docker networks for service isolation

### Data Protection

- Regular backups of PostgreSQL data
- Encrypt sensitive data in transit
- Use volume mounts for persistent storage
- Implement proper access controls

## 🐛 Troubleshooting

### Common Issues

1. **Port conflicts:**

   ```bash
   # Check what's using the ports
   netstat -tulpn | grep :3000
   # Change ports in .env file
   WEB_PORT=3001
   ```

2. **Docker not running:**

   ```bash
   # Start Docker
   sudo systemctl start docker
   # Or on macOS
   open -a Docker
   ```

3. **Insufficient memory:**

   ```bash
   # Check Docker memory allocation
   docker system df
   # Increase Docker memory limit in Docker Desktop settings
   ```

4. **Permission issues:**
   ```bash
   # Fix directory permissions
   sudo chown -R $USER:$USER ddalab/
   ```

### Logs and Debugging

```bash
# View all service logs
docker-compose logs

# View specific service logs
docker-compose logs api
docker-compose logs web

# Check service health
docker-compose ps

# Access service shell
docker-compose exec api bash
docker-compose exec postgres psql -U ddalab
```

### Health Checks

Services include health checks to ensure they're running properly:

```bash
# Check API health
curl http://localhost:8001/api/health

# Check web interface
curl http://localhost:3000

# Check database
docker-compose exec postgres pg_isready -U ddalab
```

## 📦 Docker Images

DDALAB uses the following Docker images:

- **ddalab/api:latest** - DDALAB API server
- **ddalab/web:latest** - DDALAB web interface
- **postgres:16** - PostgreSQL database
- **redis:7.4.1-alpine** - Redis cache
- **minio/minio** - Object storage for files
- **traefik:v3.3.5** - Reverse proxy and SSL termination
- **grafana/grafana:11.6.0** - Monitoring dashboard
- **prom/prometheus:v3.2.1** - Metrics collection
- **jaegertracing/jaeger:2.0.0** - Distributed tracing

## 🔄 Updates and Maintenance

### Automatic Updates

Set up automatic updates using Docker's built-in features:

```bash
# Create update script
cat > update-ddalab.sh << 'EOF'
#!/bin/bash
cd ddalab
docker-compose pull
docker-compose up -d
docker system prune -f
EOF

chmod +x update-ddalab.sh
```

### Monitoring

The deployment includes built-in monitoring tools:

- **Grafana** for dashboards and alerts
- **Prometheus** for metrics collection
- **Jaeger** for distributed tracing
- **Health checks** for all services

## 📞 Support

For issues and questions:

1. Check the troubleshooting section above
2. Review service logs: `docker-compose logs`
3. Check GitHub issues for known problems
4. Contact the DDALAB team

## 🎯 Next Steps

After successful deployment:

1. **Access the web interface** at http://localhost:3000
2. **Upload your EDF files** to the data directory
3. **Configure user accounts** and permissions
4. **Set up regular backups** of your data
5. **Monitor system resources** and performance
6. **Explore monitoring tools** at Grafana and Prometheus

---

**Happy analyzing with DDALAB! 🧠📊**
