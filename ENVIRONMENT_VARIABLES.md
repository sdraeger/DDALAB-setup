# Environment Variables Guide

This guide explains how environment variables are handled in DDALAB Docker containers and how the ConfigManager sets them up correctly.

## 🎯 Overview

DDALAB uses environment variables to configure:

- **Database connections** (PostgreSQL)
- **File storage** (MinIO)
- **Caching** (Redis)
- **Web application** (Next.js)
- **API server** (FastAPI)
- **Reverse proxy** (Traefik)

## 📋 Environment Variable Categories

### 1. Docker Image Configuration

```bash
# Use Docker Hub images instead of building locally
DDALAB_WEB_IMAGE=ddalab/web:latest
DDALAB_API_IMAGE=ddalab/api:latest
```

### 2. Database Configuration

```bash
# PostgreSQL Database
DDALAB_DB_USER=ddalab
DDALAB_DB_PASSWORD=ddalab_password
DDALAB_DB_NAME=ddalab
```

### 3. File Storage Configuration

```bash
# MinIO Object Storage
MINIO_ROOT_USER=ddalab
MINIO_ROOT_PASSWORD=ddalab_password
```

### 4. Web Application Configuration

```bash
# Next.js Environment Variables
NEXT_PUBLIC_API_URL=http://localhost:8001
NEXT_PUBLIC_APP_URL=http://localhost:3000
SESSION_EXPIRATION=10080
WEB_PORT=3000
```

### 5. API Server Configuration

```bash
# API Environment Variables
DDALAB_ALLOWED_DIRS=./data:/app/data:rw
DDALAB_DATA_DIR=./data
DDALAB_PLOT_CACHE_TTL=3600
DDALAB_REDIS_HOST=redis
DDALAB_REDIS_PORT=6379
DDALAB_REDIS_DB=0
DDALAB_REDIS_PASSWORD=
DDALAB_REDIS_USE_SSL=False
```

### 6. Reverse Proxy Configuration

```bash
# Traefik Configuration
TRAEFIK_ACME_EMAIL=admin@ddalab.local
TRAEFIK_PASSWORD_HASH=
```

## 🔧 How Environment Variables Are Passed

### 1. Docker Compose Configuration

The `docker-compose.yml` file handles environment variables in multiple ways:

```yaml
services:
  web:
    env_file:
      - ./.env # Load all variables from .env file
    environment:
      NEXT_PUBLIC_API_URL: ${NEXT_PUBLIC_API_URL:-http://localhost:8001}
      NODE_ENV: production # Direct environment variable
    volumes:
      - type: bind
        source: ./.env
        target: /app/.env # Mount .env file into container

  api:
    env_file:
      - ./.env # Load all variables from .env file
    environment:
      MINIO_HOST: "minio:9000" # Direct environment variable
      DDALAB_REDIS_HOST: redis # Direct environment variable
```

### 2. ConfigManager Setup Process

When the ConfigManager sets up a Docker deployment:

1. **Creates `.env` file** with all necessary variables
2. **Copies `docker-compose.yml`** with proper environment configuration
3. **Ensures variables are available** to all containers

## 🚀 Environment Variable Flow

### Step 1: ConfigManager Creates .env

```bash
# ConfigManager generates this .env file
NEXT_PUBLIC_API_URL=http://localhost:8001
NEXT_PUBLIC_APP_URL=http://localhost:3000
DDALAB_DB_USER=ddalab
DDALAB_DB_PASSWORD=ddalab_password
# ... more variables
```

### Step 2: Docker Compose Loads Variables

```yaml
# docker-compose.yml loads from .env file
env_file:
  - ./.env
```

### Step 3: Containers Receive Variables

```bash
# Web container receives:
NEXT_PUBLIC_API_URL=http://localhost:8001
NODE_ENV=production

# API container receives:
DDALAB_DB_USER=ddalab
MINIO_HOST=minio:9000
```

## 🔍 Environment Variable Validation

### Web Container Variables

The web container (Next.js) needs:

- ✅ `NEXT_PUBLIC_API_URL` - API server URL
- ✅ `NEXT_PUBLIC_APP_URL` - Web app URL
- ✅ `NODE_ENV` - Production/development mode
- ✅ `SESSION_EXPIRATION` - Session timeout

### API Container Variables

The API container (FastAPI) needs:

- ✅ `DDALAB_DB_USER` - Database username
- ✅ `DDALAB_DB_PASSWORD` - Database password
- ✅ `MINIO_HOST` - File storage host
- ✅ `DDALAB_REDIS_HOST` - Cache host
- ✅ `DDALAB_ALLOWED_DIRS` - File access permissions

## 🛠️ Troubleshooting Environment Variables

### Common Issues

1. **"Environment variable not found"**

   ```bash
   # Check if variable is in .env file
   grep VARIABLE_NAME .env

   # Check if Docker Compose loads it
   docker-compose config
   ```

2. **"Next.js can't find API URL"**

   ```bash
   # Ensure NEXT_PUBLIC_ variables are set
   echo $NEXT_PUBLIC_API_URL

   # Check web container environment
   docker exec -it ddalab-web-1 env | grep NEXT_PUBLIC
   ```

3. **"API can't connect to database"**

   ```bash
   # Check database variables
   docker exec -it ddalab-api-1 env | grep DDALAB_DB

   # Verify database is running
   docker-compose ps postgres
   ```

### Debugging Commands

```bash
# View all environment variables in a container
docker exec -it ddalab-web-1 env

# Check specific variable
docker exec -it ddalab-web-1 printenv NEXT_PUBLIC_API_URL

# View Docker Compose configuration
docker-compose config

# Check .env file
cat .env
```

## 🔒 Security Considerations

### Sensitive Variables

- **Database passwords** - Use strong passwords in production
- **API keys** - Store securely, never commit to git
- **Session secrets** - Use random strings

### Production Setup

```bash
# Create production .env file
cp .env.example .env.production

# Edit with production values
vim .env.production

# Use production environment
docker-compose --env-file .env.production up
```

## 📝 Environment Variable Reference

### Required Variables

| Variable              | Description           | Default                 | Required |
| --------------------- | --------------------- | ----------------------- | -------- |
| `DDALAB_DB_USER`      | Database username     | `ddalab`                | ✅       |
| `DDALAB_DB_PASSWORD`  | Database password     | `ddalab_password`       | ✅       |
| `MINIO_ROOT_USER`     | File storage username | `ddalab`                | ✅       |
| `MINIO_ROOT_PASSWORD` | File storage password | `ddalab_password`       | ✅       |
| `NEXT_PUBLIC_API_URL` | API server URL        | `http://localhost:8001` | ✅       |
| `WEB_PORT`            | Web application port  | `3000`                  | ✅       |

### Optional Variables

| Variable                | Description           | Default              |
| ----------------------- | --------------------- | -------------------- |
| `DDALAB_REDIS_PASSWORD` | Redis password        | (empty)              |
| `DDALAB_PLOT_CACHE_TTL` | Cache timeout         | `3600`               |
| `SESSION_EXPIRATION`    | Session timeout       | `10080`              |
| `TRAEFIK_ACME_EMAIL`    | SSL certificate email | `admin@ddalab.local` |

## 🎯 Best Practices

1. **Use `.env` files** for configuration
2. **Never commit secrets** to version control
3. **Validate variables** before starting containers
4. **Use descriptive names** for environment variables
5. **Document all variables** in this guide
6. **Test configurations** in development first

## 🔧 Customization

### Adding New Variables

1. **Add to `.env` file**:

   ```bash
   MY_NEW_VARIABLE=value
   ```

2. **Update `docker-compose.yml`**:

   ```yaml
   environment:
     MY_NEW_VARIABLE: ${MY_NEW_VARIABLE}
   ```

3. **Update ConfigManager** to include in generated `.env`

4. **Document** in this guide

---

**Environment variables are now properly configured for all DDALAB containers! 🚀**
