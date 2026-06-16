#!/bin/bash

# OpenMRS 3.0 Reference Application Management Script
# This script provides convenient shortcuts for common Docker Compose operations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    cat << EOF
OpenMRS 3.0 Reference Application Management Script

Usage: ./manage.sh [COMMAND] [OPTIONS]

Commands:
    up              Start the application (docker compose up)
    down            Stop the application (docker compose down)
    restart         Restart the application
    logs            View logs from all services
    logs [service]  View logs from a specific service
    build           Build the Docker images
    rebuild         Force rebuild Docker images without cache
    ps              Show running containers
    ssl             Start with SSL/HTTPS enabled
    grafana         Start with Grafana monitoring enabled
    ssl-grafana     Start with both SSL and Grafana enabled
    copy-assets     Copy frontend assets to container without rebuilding
    clean           Remove all containers, volumes, and images
    cert-renew      Force SSL certificate renewal
    cert-check      Check SSL certificate expiration
    help            Show this help message

Examples:
    ./manage.sh up                  # Start the application
    ./manage.sh logs backend        # View backend logs
    ./manage.sh ssl                 # Start with SSL
    ./manage.sh rebuild             # Force rebuild all containers
    ./manage.sh copy-assets         # Copy frontend assets without rebuild
    ./manage.sh clean               # Clean up everything

For more information, see README.md
EOF
}

# Function to start the application
cmd_up() {
    print_info "Starting OpenMRS 3.0 Reference Application..."
    docker compose up -d
    print_success "Application started!"
    print_info "OpenMRS 3.x UI: http://localhost/openmrs/spa"
    print_info "OpenMRS Legacy UI: http://localhost/openmrs"
}

# Function to stop the application
cmd_down() {
    print_info "Stopping OpenMRS 3.0 Reference Application..."
    docker compose down
    print_success "Application stopped!"
}

# Function to restart the application
cmd_restart() {
    print_info "Restarting OpenMRS 3.0 Reference Application..."
    docker compose restart
    print_success "Application restarted!"
}

# Function to view logs
cmd_logs() {
    if [ -n "$1" ]; then
        print_info "Viewing logs for service: $1"
        docker compose logs -f "$1"
    else
        print_info "Viewing logs for all services..."
        docker compose logs -f
    fi
}

# Function to build images
cmd_build() {
    print_info "Building Docker images..."
    docker compose build
    print_success "Build completed!"
}

# Function to rebuild images without cache
cmd_rebuild() {
    print_info "Rebuilding Docker images without cache..."
    docker compose build --no-cache
    print_success "Rebuild completed!"
}

# Function to show running containers
cmd_ps() {
    print_info "Running containers:"
    docker compose ps
}

# Function to copy frontend assets to container
cmd_copy_assets() {
    print_info "Copying frontend assets to container..."
    
    # Check if frontend container is running
    FRONTEND_CONTAINER=$(docker compose ps -q frontend)
    
    if [ -z "$FRONTEND_CONTAINER" ]; then
        print_error "Frontend container is not running!"
        print_info "Please start the application first: ./manage.sh up"
        exit 1
    fi
    
    # Check if frontend assets directory exists
    if [ ! -d "frontend" ]; then
        print_error "Frontend directory not found!"
        exit 1
    fi
    
    # Copy assets to the running container
    # Assuming the frontend container serves from /usr/share/nginx/html
    print_info "Copying assets from ./frontend to frontend container..."
    docker compose cp frontend/. frontend:/usr/share/nginx/html/ 2>/dev/null || {
        print_warning "Could not copy to /usr/share/nginx/html, trying alternative paths..."
        docker compose cp frontend/. frontend:/var/www/ || {
            print_error "Failed to copy assets to frontend container"
            exit 1
        }
    }
    
    # Restart frontend service to pick up changes
    print_info "Restarting frontend service..."
    docker compose restart frontend
    
    print_success "Frontend assets copied and service restarted!"
    print_info "Changes should be visible at: http://localhost/openmrs/spa"
}

# Function to start with SSL
cmd_ssl() {
    print_info "Starting OpenMRS 3.0 with SSL/HTTPS enabled..."
    docker compose -f docker-compose.yml -f docker-compose.ssl.yml up -d
    print_success "Application started with SSL!"
    print_info "OpenMRS 3.x UI: https://localhost/openmrs/spa"
    print_info "OpenMRS Legacy UI: https://localhost/openmrs"
}

# Function to start with Grafana
cmd_grafana() {
    print_info "Starting OpenMRS 3.0 with Grafana monitoring..."
    docker compose -f docker-compose.yml -f docker-compose.grafana.yml up -d
    print_success "Application started with Grafana!"
    print_info "OpenMRS 3.x UI: http://localhost/openmrs/spa"
    print_info "Grafana: http://localhost/grafana"
}

# Function to start with SSL and Grafana
cmd_ssl_grafana() {
    print_info "Starting OpenMRS 3.0 with SSL and Grafana..."
    docker compose -f docker-compose.yml -f docker-compose.ssl.yml -f docker-compose.grafana.yml up -d
    print_success "Application started with SSL and Grafana!"
    print_info "OpenMRS 3.x UI: https://localhost/openmrs/spa"
    print_info "Grafana: https://localhost/grafana"
}

# Function to clean up everything
cmd_clean() {
    print_warning "This will remove all containers, volumes, and images!"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Stopping and removing containers..."
        docker compose down -v --remove-orphans
        
        print_info "Removing volumes..."
        PROJECT_NAME=$(docker compose config | awk '/^name:/{print $2}')
        docker volume rm "${PROJECT_NAME}_openmrs-data" 2>/dev/null || true
        docker volume rm "${PROJECT_NAME}_db-data" 2>/dev/null || true
        docker volume rm "${PROJECT_NAME}_letsencrypt-data" 2>/dev/null || true
        
        print_info "Removing images..."
        docker compose down --rmi all
        
        print_success "Cleanup completed!"
    else
        print_info "Cleanup cancelled."
    fi
}

# Function to renew SSL certificates
cmd_cert_renew() {
    print_info "Forcing SSL certificate renewal..."
    docker compose exec certbot certbot renew --force-renewal --webroot -w /var/www/certbot
    docker compose exec gateway nginx -s reload
    print_success "Certificate renewed and nginx reloaded!"
}

# Function to check SSL certificate expiration
cmd_cert_check() {
    print_info "Checking SSL certificate expiration..."
    docker compose exec certbot certbot certificates
}

# Main script logic
case "${1:-help}" in
    up)
        cmd_up
        ;;
    down)
        cmd_down
        ;;
    restart)
        cmd_restart
        ;;
    logs)
        cmd_logs "$2"
        ;;
    build)
        cmd_build
        ;;
    rebuild)
        cmd_rebuild
        ;;
    ps)
        cmd_ps
        ;;
    ssl)
        cmd_ssl
        ;;
    grafana)
        cmd_grafana
        ;;
    ssl-grafana)
        cmd_ssl_grafana
        ;;
    copy-assets)
        cmd_copy_assets
        ;;
    clean)
        cmd_clean
        ;;
    cert-renew)
        cmd_cert_renew
        ;;
    cert-check)
        cmd_cert_check
        ;;
    help|--help|-h)
        show_usage
        ;;
    *)
        print_error "Unknown command: $1"
        echo ""
        show_usage
        exit 1
        ;;
esac
