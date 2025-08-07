#!/bin/bash

# AWS EC2 Setup Script for E-Commerce Microservices
# This script automates the setup of our microservices platform on AWS

set -e  # Exit on any error

echo "🚀 Starting AWS EC2 Setup for E-Commerce Microservices Platform"
echo "================================================================"

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

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   print_error "This script should not be run as root. Please run as ec2-user"
   exit 1
fi

# Check if we're on Amazon Linux
if ! grep -q "Amazon Linux" /etc/os-release; then
    print_warning "This script is designed for Amazon Linux. You may need to adjust package manager commands."
fi

print_status "Updating system packages..."
sudo yum update -y

print_status "Installing required packages..."
sudo yum install -y git docker docker-compose-plugin curl wget vim htop httpd-tools

print_status "Starting and enabling Docker service..."
sudo systemctl start docker
sudo systemctl enable docker

print_status "Adding ec2-user to docker group..."
sudo usermod -aG docker ec2-user

print_status "Creating project directory..."
mkdir -p ~/ecommerce-devops
cd ~/ecommerce-devops

print_status "Cloning the repository..."
git clone https://github.com/vpodugu/ecommerce-devops-platform.git .
if [ $? -eq 0 ]; then
    print_success "Repository cloned successfully"
else
    print_error "Failed to clone repository"
    exit 1
fi

print_status "Creating environment configuration..."
cat > .env << EOF
# Database Configuration
MYSQL_ROOT_PASSWORD=rootpassword
MYSQL_USER=user_service
MYSQL_PASSWORD=user_service_pass

# Service URLs (for inter-service communication)
USER_SERVICE_URL=http://user-service:3001
PRODUCT_SERVICE_URL=http://product-service:3002
ORDER_SERVICE_URL=http://order-service:3003

# Redis Configuration
REDIS_PASSWORD=redis_password

# Environment
NODE_ENV=production

# API Gateway Configuration
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:80,http://localhost:8080
EOF

print_success "Environment configuration created"

print_status "Building Docker images..."
docker-compose build
if [ $? -eq 0 ]; then
    print_success "Docker images built successfully"
else
    print_error "Failed to build Docker images"
    exit 1
fi

print_status "Starting all services..."
docker-compose up -d
if [ $? -eq 0 ]; then
    print_success "Services started successfully"
else
    print_error "Failed to start services"
    exit 1
fi

print_status "Waiting for services to be ready..."
sleep 30

print_status "Checking service health..."

# Function to check service health
check_service_health() {
    local service_name=$1
    local port=$2
    local endpoint=$3
    
    print_status "Checking $service_name health..."
    response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$port$endpoint)
    
    if [ "$response" = "200" ]; then
        print_success "$service_name is healthy (HTTP $response)"
        return 0
    else
        print_error "$service_name health check failed (HTTP $response)"
        return 1
    fi
}

# Check each service
services_healthy=true

check_service_health "User Service" "3001" "/health" || services_healthy=false
check_service_health "Product Service" "3002" "/health" || services_healthy=false
check_service_health "Order Service" "3003" "/health" || services_healthy=false
check_service_health "API Gateway" "8080" "/health" || services_healthy=false

if [ "$services_healthy" = true ]; then
    print_success "All services are healthy!"
else
    print_warning "Some services may not be fully ready. Check logs with: docker-compose logs"
fi

print_status "Checking database connectivity..."
# Check if databases are accessible
docker exec ecommerce_user_db mysql -u root -prootpassword -e "SELECT 1;" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    print_success "User Service database is accessible"
else
    print_error "User Service database is not accessible"
fi

docker exec ecommerce_product_db mysql -u root -prootpassword -e "SELECT 1;" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    print_success "Product Service database is accessible"
else
    print_error "Product Service database is not accessible"
fi

docker exec ecommerce_order_db mysql -u root -prootpassword -e "SELECT 1;" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    print_success "Order Service database is accessible"
else
    print_error "Order Service database is not accessible"
fi

print_status "Creating test script..."
cat > test-services.sh << 'EOF'
#!/bin/bash

echo "🧪 Testing E-Commerce Microservices APIs"
echo "========================================"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Testing API Gateway root endpoint...${NC}"
curl -s http://localhost:8080/ | jq '.'

echo -e "\n${BLUE}Testing User Service APIs...${NC}"
echo "Getting users:"
curl -s http://localhost:8080/api/users | jq '.'

echo -e "\n${BLUE}Testing Product Service APIs...${NC}"
echo "Getting products:"
curl -s "http://localhost:8080/api/products?limit=3" | jq '.'

echo "Getting categories:"
curl -s http://localhost:8080/api/categories | jq '.'

echo -e "\n${BLUE}Testing Order Service APIs...${NC}"
echo "Getting orders:"
curl -s http://localhost:8080/api/orders | jq '.'

echo -e "\n${GREEN}✅ Basic API testing completed!${NC}"
EOF

chmod +x test-services.sh

print_status "Creating monitoring script..."
cat > monitor-services.sh << 'EOF'
#!/bin/bash

echo "📊 E-Commerce Microservices Monitoring"
echo "======================================"

echo "Container Status:"
docker-compose ps

echo -e "\nResource Usage:"
docker stats --no-stream

echo -e "\nService Health:"
echo "User Service: $(curl -s -o /dev/null -w "%{http_code}" http://localhost:3001/health)"
echo "Product Service: $(curl -s -o /dev/null -w "%{http_code}" http://localhost:3002/health)"
echo "Order Service: $(curl -s -o /dev/null -w "%{http_code}" http://localhost:3003/health)"
echo "API Gateway: $(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/health)"

echo -e "\nRecent Logs (last 10 lines):"
docker-compose logs --tail=10
EOF

chmod +x monitor-services.sh

print_status "Creating cleanup script..."
cat > cleanup.sh << 'EOF'
#!/bin/bash

echo "🧹 Cleaning up E-Commerce Microservices"
echo "======================================="

echo "Stopping all services..."
docker-compose down

echo "Removing all containers and volumes..."
docker-compose down -v

echo "Removing all images..."
docker rmi $(docker images -q) 2>/dev/null || echo "No images to remove"

echo "Cleanup completed!"
EOF

chmod +x cleanup.sh

# Display final status
echo ""
echo "🎉 Setup Complete!"
echo "=================="
print_success "E-Commerce Microservices Platform is now running on your AWS EC2 instance!"

echo ""
echo "📋 Service Information:"
echo "  • API Gateway: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"
echo "  • User Service: http://localhost:3001"
echo "  • Product Service: http://localhost:3002"
echo "  • Order Service: http://localhost:3003"
echo "  • API Documentation: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080/api-docs"

echo ""
echo "🔧 Available Scripts:"
echo "  • ./test-services.sh - Test all APIs"
echo "  • ./monitor-services.sh - Monitor service status"
echo "  • ./cleanup.sh - Clean up all containers and images"

echo ""
echo "📝 Useful Commands:"
echo "  • docker-compose ps - View service status"
echo "  • docker-compose logs -f - Follow logs"
echo "  • docker-compose logs [service-name] - View specific service logs"
echo "  • docker stats - Monitor resource usage"

echo ""
print_warning "Important: You may need to log out and log back in for Docker group permissions to take effect."

echo ""
echo "🚀 Ready for Phase 2: GitHub Actions CI/CD!"
echo "============================================="
