#!/bin/bash

# Manual Docker Cleanup Script for E-Commerce Microservices
# This script cleans up all containers, volumes, networks, and images created by manual deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
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

# Function to check if container exists
container_exists() {
    docker ps -a --format "table {{.Names}}" | grep -q "^$1$"
}

# Function to check if volume exists
volume_exists() {
    docker volume ls --format "table {{.Name}}" | grep -q "^$1$"
}

# Function to check if network exists
network_exists() {
    docker network ls --format "table {{.Name}}" | grep -q "^$1$"
}

# Function to check if image exists
image_exists() {
    docker images --format "table {{.Repository}}:{{.Tag}}" | grep -q "^$1$"
}

print_status "Starting cleanup of manual Docker deployment..."

# Step 1: Stop and Remove Containers
print_status "Step 1: Stopping and removing containers..."

# Microservice containers
containers=(
    "ecommerce-user-service"
    "ecommerce-product-service"
    "ecommerce-order-service"
    "ecommerce-api-gateway"
    "ecommerce-frontend"
    "ecommerce_user_db"
    "ecommerce_product_db"
    "ecommerce_order_db"
    "ecommerce_redis"
)

for container in "${containers[@]}"; do
    if container_exists "$container"; then
        print_status "Stopping container: $container"
        docker stop "$container" 2>/dev/null || print_warning "Container $container was not running"
        
        print_status "Removing container: $container"
        docker rm "$container" 2>/dev/null || print_warning "Container $container was already removed"
        print_success "Container $container cleaned up"
    else
        print_warning "Container $container does not exist"
    fi
done

# Step 2: Remove Volumes
print_status "Step 2: Removing volumes..."

volumes=(
    "user_db_data"
    "product_db_data"
    "order_db_data"
    "redis_data"
)

for volume in "${volumes[@]}"; do
    if volume_exists "$volume"; then
        print_status "Removing volume: $volume"
        docker volume rm "$volume" 2>/dev/null || print_warning "Volume $volume could not be removed"
        print_success "Volume $volume removed"
    else
        print_warning "Volume $volume does not exist"
    fi
done

# Step 3: Remove Network
print_status "Step 3: Removing network..."

if network_exists "ecommerce-network"; then
    print_status "Removing network: ecommerce-network"
    docker network rm ecommerce-network 2>/dev/null || print_warning "Network ecommerce-network could not be removed"
    print_success "Network ecommerce-network removed"
else
    print_warning "Network ecommerce-network does not exist"
fi

# Step 4: Remove Images
print_status "Step 4: Removing images..."

images=(
    "ecommerce/user-service:latest"
    "ecommerce/product-service:latest"
    "ecommerce/order-service:latest"
    "ecommerce/api-gateway:latest"
    "ecommerce/frontend:latest"
)

for image in "${images[@]}"; do
    if image_exists "$image"; then
        print_status "Removing image: $image"
        docker rmi "$image" 2>/dev/null || print_warning "Image $image could not be removed"
        print_success "Image $image removed"
    else
        print_warning "Image $image does not exist"
    fi
done

# Step 5: Clean up dangling resources
print_status "Step 5: Cleaning up dangling resources..."

# Remove dangling images
dangling_images=$(docker images -f "dangling=true" -q)
if [ -n "$dangling_images" ]; then
    print_status "Removing dangling images..."
    docker rmi "$dangling_images" 2>/dev/null || print_warning "Some dangling images could not be removed"
    print_success "Dangling images removed"
else
    print_status "No dangling images found"
fi

# Remove unused networks
unused_networks=$(docker network ls --filter "type=custom" --format "{{.Name}}" | grep -v "bridge\|host\|none")
if [ -n "$unused_networks" ]; then
    print_status "Removing unused networks..."
    echo "$unused_networks" | while read -r network; do
        if [ "$network" != "ecommerce-network" ]; then
            docker network rm "$network" 2>/dev/null || print_warning "Network $network could not be removed"
        fi
    done
    print_success "Unused networks removed"
else
    print_status "No unused networks found"
fi

# Step 6: Verify Cleanup
print_status "Step 6: Verifying cleanup..."

# Check for remaining containers
remaining_containers=$(docker ps -a --format "table {{.Names}}" | grep -E "(ecommerce|user|product|order|api|frontend)" || true)
if [ -n "$remaining_containers" ]; then
    print_warning "Some containers still exist:"
    echo "$remaining_containers"
else
    print_success "All ecommerce containers removed"
fi

# Check for remaining volumes
remaining_volumes=$(docker volume ls --format "table {{.Name}}" | grep -E "(user|product|order|redis)_db_data" || true)
if [ -n "$remaining_volumes" ]; then
    print_warning "Some volumes still exist:"
    echo "$remaining_volumes"
else
    print_success "All ecommerce volumes removed"
fi

# Check for remaining images
remaining_images=$(docker images --format "table {{.Repository}}:{{.Tag}}" | grep "ecommerce/" || true)
if [ -n "$remaining_images" ]; then
    print_warning "Some images still exist:"
    echo "$remaining_images"
else
    print_success "All ecommerce images removed"
fi

# Check for remaining network
if network_exists "ecommerce-network"; then
    print_warning "Network ecommerce-network still exists"
else
    print_success "Network ecommerce-network removed"
fi

print_success "Cleanup completed!"

# Display system status
echo ""
echo "=== System Status ==="
echo "Containers: $(docker ps -q | wc -l) running, $(docker ps -aq | wc -l) total"
echo "Images: $(docker images -q | wc -l) total"
echo "Volumes: $(docker volume ls -q | wc -l) total"
echo "Networks: $(docker network ls -q | wc -l) total"
echo ""
echo "=== Disk Usage ==="
docker system df
echo ""
echo "=== Cleanup Options ==="
echo "Remove all unused data: docker system prune -a"
echo "Remove all images: docker rmi \$(docker images -q)"
echo "Remove all volumes: docker volume prune"
echo "Remove all networks: docker network prune"
echo ""
