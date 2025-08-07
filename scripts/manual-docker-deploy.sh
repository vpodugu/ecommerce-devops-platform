#!/bin/bash

# Manual Docker Deployment Script for E-Commerce Microservices
# This script demonstrates manual container deployment without Docker Compose

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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to wait for service to be ready
wait_for_service() {
    local service_name=$1
    local port=$2
    local max_attempts=30
    local attempt=1
    
    print_status "Waiting for $service_name to be ready on port $port..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s "http://localhost:$port/health" >/dev/null 2>&1; then
            print_success "$service_name is ready!"
            return 0
        fi
        
        echo -n "."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    print_error "$service_name failed to start within $((max_attempts * 2)) seconds"
    return 1
}

# Check prerequisites
print_status "Checking prerequisites..."

if ! command_exists docker; then
    print_error "Docker is not installed. Please install Docker first."
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    print_error "Docker daemon is not running. Please start Docker."
    exit 1
fi

if ! command_exists jq; then
    print_warning "jq is not installed. Installing jq..."
    sudo yum install -y jq || sudo apt-get install -y jq
fi

# Check if we're in the project directory
if [ ! -f "docker-compose.yml" ]; then
    print_error "Please run this script from the ecommerce-devops project root directory"
    exit 1
fi

print_success "Prerequisites check passed!"

# Step 1: Create Docker Network
print_status "Step 1: Creating Docker network..."
docker network create ecommerce-network 2>/dev/null || print_warning "Network ecommerce-network already exists"
print_success "Docker network created"

# Step 2: Start Database Containers
print_status "Step 2: Starting database containers..."

# User Service Database
print_status "Starting User Service Database..."
docker run -d \
  --name ecommerce_user_db \
  --network ecommerce-network \
  -e MYSQL_ROOT_PASSWORD=rootpassword \
  -e MYSQL_DATABASE=user_service \
  -e MYSQL_USER=user_service \
  -e MYSQL_PASSWORD=user_service_pass \
  -p 3306:3306 \
  -v user_db_data:/var/lib/mysql \
  -v $(pwd)/services/user-service/database/init.sql:/docker-entrypoint-initdb.d/init.sql \
  --restart unless-stopped \
  mysql:8.0

# Product Service Database
print_status "Starting Product Service Database..."
docker run -d \
  --name ecommerce_product_db \
  --network ecommerce-network \
  -e MYSQL_ROOT_PASSWORD=rootpassword \
  -e MYSQL_DATABASE=product_service \
  -e MYSQL_USER=product_service \
  -e MYSQL_PASSWORD=product_service_pass \
  -p 3307:3306 \
  -v product_db_data:/var/lib/mysql \
  -v $(pwd)/services/product-service/database/init.sql:/docker-entrypoint-initdb.d/init.sql \
  --restart unless-stopped \
  mysql:8.0

# Order Service Database
print_status "Starting Order Service Database..."
docker run -d \
  --name ecommerce_order_db \
  --network ecommerce-network \
  -e MYSQL_ROOT_PASSWORD=rootpassword \
  -e MYSQL_DATABASE=order_service \
  -e MYSQL_USER=order_service \
  -e MYSQL_PASSWORD=order_service_pass \
  -p 3308:3306 \
  -v order_db_data:/var/lib/mysql \
  -v $(pwd)/services/order-service/database/init.sql:/docker-entrypoint-initdb.d/init.sql \
  --restart unless-stopped \
  mysql:8.0

# Redis Cache
print_status "Starting Redis Cache..."
docker run -d \
  --name ecommerce_redis \
  --network ecommerce-network \
  -e REDIS_PASSWORD=redis_password \
  -p 6379:6379 \
  -v redis_data:/data \
  --restart unless-stopped \
  redis:7-alpine redis-server --requirepass redis_password

print_success "All database containers started"

# Step 3: Wait for Databases to Initialize
print_status "Step 3: Waiting for databases to initialize..."
sleep 30

# Verify database containers
print_status "Verifying database containers..."
docker ps | grep -E "(mysql|redis)" || print_error "Database containers not running"

# Test database connections
print_status "Testing database connections..."
docker exec ecommerce_user_db mysql -u root -prootpassword -e "SELECT 1;" 2>/dev/null && print_success "User DB Ready" || print_error "User DB Not Ready"
docker exec ecommerce_product_db mysql -u root -prootpassword -e "SELECT 1;" 2>/dev/null && print_success "Product DB Ready" || print_error "Product DB Not Ready"
docker exec ecommerce_order_db mysql -u root -prootpassword -e "SELECT 1;" 2>/dev/null && print_success "Order DB Ready" || print_error "Order DB Not Ready"

# Step 4: Build Microservice Images
print_status "Step 4: Building microservice images..."

print_status "Building User Service..."
docker build -t ecommerce/user-service:latest ./services/user-service/

print_status "Building Product Service..."
docker build -t ecommerce/product-service:latest ./services/product-service/

print_status "Building Order Service..."
docker build -t ecommerce/order-service:latest ./services/order-service/

print_status "Building API Gateway..."
docker build -t ecommerce/api-gateway:latest ./services/api-gateway/

print_status "Building Frontend..."
docker build -t ecommerce/frontend:latest ./frontend/

print_success "All images built successfully"

# Step 5: Start Microservice Containers
print_status "Step 5: Starting microservice containers..."

# User Service
print_status "Starting User Service..."
docker run -d \
  --name ecommerce-user-service \
  --network ecommerce-network \
  -p 3001:3001 \
  -e NODE_ENV=production \
  -e DB_HOST=ecommerce_user_db \
  -e DB_PORT=3306 \
  -e DB_USER=user_service \
  -e DB_PASSWORD=user_service_pass \
  -e DB_NAME=user_service \
  -e REDIS_HOST=ecommerce_redis \
  -e REDIS_PORT=6379 \
  -e REDIS_PASSWORD=redis_password \
  -e JWT_SECRET=your-super-secret-jwt-key \
  --restart unless-stopped \
  ecommerce/user-service:latest

# Product Service
print_status "Starting Product Service..."
docker run -d \
  --name ecommerce-product-service \
  --network ecommerce-network \
  -p 3002:3002 \
  -e NODE_ENV=production \
  -e DB_HOST=ecommerce_product_db \
  -e DB_PORT=3306 \
  -e DB_USER=product_service \
  -e DB_PASSWORD=product_service_pass \
  -e DB_NAME=product_service \
  -e REDIS_HOST=ecommerce_redis \
  -e REDIS_PORT=6379 \
  -e REDIS_PASSWORD=redis_password \
  --restart unless-stopped \
  ecommerce/product-service:latest

# Order Service
print_status "Starting Order Service..."
docker run -d \
  --name ecommerce-order-service \
  --network ecommerce-network \
  -p 3003:3003 \
  -e NODE_ENV=production \
  -e DB_HOST=ecommerce_order_db \
  -e DB_PORT=3306 \
  -e DB_USER=order_service \
  -e DB_PASSWORD=order_service_pass \
  -e DB_NAME=order_service \
  -e REDIS_HOST=ecommerce_redis \
  -e REDIS_PORT=6379 \
  -e REDIS_PASSWORD=redis_password \
  -e USER_SERVICE_URL=http://ecommerce-user-service:3001 \
  -e PRODUCT_SERVICE_URL=http://ecommerce-product-service:3002 \
  --restart unless-stopped \
  ecommerce/order-service:latest

# API Gateway
print_status "Starting API Gateway..."
docker run -d \
  --name ecommerce-api-gateway \
  --network ecommerce-network \
  -p 8080:8080 \
  -e NODE_ENV=production \
  -e USER_SERVICE_URL=http://ecommerce-user-service:3001 \
  -e PRODUCT_SERVICE_URL=http://ecommerce-product-service:3002 \
  -e ORDER_SERVICE_URL=http://ecommerce-order-service:3003 \
  --restart unless-stopped \
  ecommerce/api-gateway:latest

# Frontend
print_status "Starting Frontend..."
docker run -d \
  --name ecommerce-frontend \
  --network ecommerce-network \
  -p 80:80 \
  -e REACT_APP_API_URL=http://localhost:8080 \
  --restart unless-stopped \
  ecommerce/frontend:latest

print_success "All microservice containers started"

# Step 6: Verify Deployment
print_status "Step 6: Verifying deployment..."

# Check all containers status
print_status "Checking container status..."
docker ps

# Wait for services to be ready
print_status "Waiting for services to be ready..."
wait_for_service "User Service" 3001
wait_for_service "Product Service" 3002
wait_for_service "Order Service" 3003
wait_for_service "API Gateway" 8080

# Test health endpoints
print_status "Testing health endpoints..."
echo "User Service: $(curl -s http://localhost:3001/health | jq -r '.status' 2>/dev/null || echo 'Not responding')"
echo "Product Service: $(curl -s http://localhost:3002/health | jq -r '.status' 2>/dev/null || echo 'Not responding')"
echo "Order Service: $(curl -s http://localhost:3003/health | jq -r '.status' 2>/dev/null || echo 'Not responding')"
echo "API Gateway: $(curl -s http://localhost:8080/health | jq -r '.status' 2>/dev/null || echo 'Not responding')"

# Test frontend
if curl -s -I http://localhost:80 | grep -q "200 OK"; then
    print_success "Frontend is responding"
else
    print_warning "Frontend may not be ready yet"
fi

print_success "Manual deployment completed successfully!"

# Display service URLs
echo ""
echo "=== Service URLs ==="
echo "Frontend: http://localhost:80"
echo "API Gateway: http://localhost:8080"
echo "User Service: http://localhost:3001"
echo "Product Service: http://localhost:3002"
echo "Order Service: http://localhost:3003"
echo ""
echo "=== Database Ports ==="
echo "User DB: localhost:3306"
echo "Product DB: localhost:3307"
echo "Order DB: localhost:3308"
echo "Redis: localhost:6379"
echo ""
echo "=== Useful Commands ==="
echo "View logs: docker logs -f <container-name>"
echo "Stop service: docker stop <container-name>"
echo "Restart service: docker restart <container-name>"
echo "Check status: docker ps"
echo "Cleanup: ./scripts/manual-docker-cleanup.sh"
echo ""
