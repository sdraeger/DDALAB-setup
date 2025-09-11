#!/bin/bash
# DDALAB Management Script for Linux/macOS

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
print_banner() {
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════╗"
    echo "║          DDALAB Management Tool          ║"
    echo "╚══════════════════════════════════════════╝"
    echo -e "${NC}"
}

check_requirements() {
    echo "Checking requirements..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Error: Docker is not installed${NC}"
        echo "Please install Docker from https://docs.docker.com/get-docker/"
        exit 1
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        echo -e "${RED}Error: Docker Compose is not installed${NC}"
        echo "Please install Docker Compose from https://docs.docker.com/compose/install/"
        exit 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        echo -e "${RED}Error: Docker daemon is not running${NC}"
        echo "Please start Docker Desktop or the Docker service"
        exit 1
    fi
    
    echo -e "${GREEN}✓ All requirements met${NC}"
}

setup_environment() {
    if [ ! -f .env ]; then
        echo -e "${YELLOW}No .env file found. Creating from template...${NC}"
        cp .env.example .env
        
        # Generate secure passwords
        echo "Generating secure passwords..."
        
        # Function to generate password
        gen_password() {
            openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
        }
        
        # Update passwords in .env
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            sed -i '' "s/DB_PASSWORD=.*/DB_PASSWORD=$(gen_password)/" .env
            sed -i '' "s/MINIO_ROOT_PASSWORD=.*/MINIO_ROOT_PASSWORD=$(gen_password)/" .env
            sed -i '' "s/JWT_SECRET_KEY=.*/JWT_SECRET_KEY=$(gen_password)/" .env
            sed -i '' "s/NEXTAUTH_SECRET=.*/NEXTAUTH_SECRET=$(gen_password)/" .env
        else
            # Linux
            sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=$(gen_password)/" .env
            sed -i "s/MINIO_ROOT_PASSWORD=.*/MINIO_ROOT_PASSWORD=$(gen_password)/" .env
            sed -i "s/JWT_SECRET_KEY=.*/JWT_SECRET_KEY=$(gen_password)/" .env
            sed -i "s/NEXTAUTH_SECRET=.*/NEXTAUTH_SECRET=$(gen_password)/" .env
        fi
        
        echo -e "${GREEN}✓ Environment file created with secure passwords${NC}"
        echo -e "${YELLOW}Please review .env and update any settings as needed${NC}"
    else
        echo -e "${GREEN}✓ Environment file exists${NC}"
    fi
}

setup_ssl() {
    if [ ! -f certs/cert.pem ] || [ ! -f certs/key.pem ]; then
        echo -e "${YELLOW}SSL certificates not found. Generating self-signed certificates...${NC}"
        ./scripts/generate-certs.sh
        echo -e "${GREEN}✓ SSL certificates generated${NC}"
    else
        echo -e "${GREEN}✓ SSL certificates exist${NC}"
    fi
}

start_services() {
    echo "Starting DDALAB services..."
    
    # Use docker compose v2 if available, otherwise fall back to docker-compose
    if docker compose version &> /dev/null; then
        COMPOSE_CMD="docker compose"
    else
        COMPOSE_CMD="docker-compose"
    fi
    
    # Pull latest images
    echo "Pulling latest images..."
    $COMPOSE_CMD pull
    
    # Start services
    $COMPOSE_CMD up -d
    
    # Wait for services to be ready
    echo "Waiting for services to start..."
    sleep 10
    
    # Check service health
    echo ""
    echo "Service Status:"
    $COMPOSE_CMD ps
    
    # Get the domain from .env
    DOMAIN=$(grep "^DOMAIN=" .env | cut -d'=' -f2 || echo "localhost")
    
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                    DDALAB Started!                       ║${NC}"
    echo -e "${GREEN}╠══════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║  Access DDALAB at: https://${DOMAIN}                      ${NC}"
    echo -e "${GREEN}║  MinIO Console at: http://${DOMAIN}:9001                  ${NC}"
    echo -e "${GREEN}║                                                          ║${NC}"
    echo -e "${GREEN}║  Default credentials:                                    ║${NC}"
    echo -e "${GREEN}║  Email: admin@example.com                                ║${NC}"
    echo -e "${GREEN}║  Password: admin (CHANGE THIS!)                          ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
}

stop_services() {
    echo "Stopping DDALAB services..."
    
    if docker compose version &> /dev/null; then
        COMPOSE_CMD="docker compose"
    else
        COMPOSE_CMD="docker-compose"
    fi
    
    $COMPOSE_CMD down
    echo -e "${GREEN}✓ DDALAB stopped${NC}"
}

show_logs() {
    if docker compose version &> /dev/null; then
        COMPOSE_CMD="docker compose"
    else
        COMPOSE_CMD="docker-compose"
    fi
    
    $COMPOSE_CMD logs -f
}

show_status() {
    if docker compose version &> /dev/null; then
        COMPOSE_CMD="docker compose"
    else
        COMPOSE_CMD="docker-compose"
    fi
    
    echo "DDALAB Service Status:"
    $COMPOSE_CMD ps
}

backup_data() {
    echo "Creating backup..."
    ./scripts/backup.sh
}

update_system() {
    echo -e "${YELLOW}Updating DDALAB system...${NC}"
    
    # Check if we're in a git repository
    if [ ! -d ".git" ]; then
        echo -e "${RED}Error: Not in a git repository${NC}"
        echo "Please navigate to the DDALAB project root directory"
        exit 1
    fi
    
    # Check for uncommitted changes
    if ! git diff-index --quiet HEAD --; then
        echo -e "${YELLOW}Warning: You have uncommitted changes${NC}"
        echo "Uncommitted changes:"
        git status --porcelain
        echo ""
        read -p "Continue with update? This may overwrite local changes (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Update cancelled"
            exit 1
        fi
    fi
    
    # Save current branch
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    echo "Current branch: $CURRENT_BRANCH"
    
    # Pull latest changes
    echo "Pulling latest changes from git..."
    if ! git pull origin "$CURRENT_BRANCH"; then
        echo -e "${RED}Error: Git pull failed${NC}"
        echo "Please resolve any conflicts manually and run the update again"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Git pull completed successfully${NC}"
    
    # Update Docker images and restart services
    echo "Updating Docker images and restarting services..."
    
    # Use docker compose v2 if available
    if docker compose version &> /dev/null; then
        COMPOSE_CMD="docker compose"
    else
        COMPOSE_CMD="docker-compose"
    fi
    
    # Stop current services
    echo "Stopping current services..."
    $COMPOSE_CMD down
    
    # Pull latest images
    echo "Pulling latest Docker images..."
    $COMPOSE_CMD pull
    
    # Rebuild and start services
    echo "Rebuilding and starting services..."
    $COMPOSE_CMD up -d --build
    
    # Wait for services
    echo "Waiting for services to start..."
    sleep 15
    
    # Show status
    echo ""
    echo "Update completed! Service status:"
    $COMPOSE_CMD ps
    
    # Get the domain from .env
    DOMAIN=$(grep "^DOMAIN=" .env | cut -d'=' -f2 || echo "localhost")
    
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                  DDALAB Update Complete!                 ║${NC}"
    echo -e "${GREEN}╠══════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║  Access DDALAB at: https://${DOMAIN}                      ${NC}"
    echo -e "${GREEN}║  All services have been updated and restarted            ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
}

# Main script
print_banner

case "$1" in
    start)
        check_requirements
        setup_environment
        setup_ssl
        start_services
        ;;
    stop)
        stop_services
        ;;
    restart)
        stop_services
        sleep 5
        start_services
        ;;
    update)
        check_requirements
        update_system
        ;;
    logs)
        show_logs
        ;;
    status)
        show_status
        ;;
    backup)
        backup_data
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|update|logs|status|backup}"
        echo ""
        echo "Commands:"
        echo "  start    - Start DDALAB (sets up environment if needed)"
        echo "  stop     - Stop DDALAB"
        echo "  restart  - Restart DDALAB"
        echo "  update   - Update DDALAB (git pull + rebuild Docker images)"
        echo "  logs     - Show service logs (follow mode)"
        echo "  status   - Show service status"
        echo "  backup   - Create database backup"
        exit 1
        ;;
esac