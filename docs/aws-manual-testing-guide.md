# AWS Manual Testing Guide - Phase 1

## Overview
This guide walks through setting up and testing the complete e-commerce microservices platform on an AWS EC2 instance. This validates our Phase 1 implementation before moving to automated DevOps processes.

## Prerequisites
- AWS Account with EC2 access
- SSH key pair configured
- Basic knowledge of AWS EC2 and Linux commands

## Step 1: Launch EC2 Instance

### Instance Configuration
- **Instance Type**: t3.medium (2 vCPU, 4 GB RAM) - sufficient for testing
- **AMI**: Amazon Linux 2023 (latest)
- **Storage**: 20 GB gp3 (expandable)
- **Security Group**: Custom with required ports

### Security Group Rules
```
Inbound Rules:
- SSH (22) - Your IP
- HTTP (80) - 0.0.0.0/0
- HTTPS (443) - 0.0.0.0/0 (optional)
- Custom TCP (3000-3003) - 0.0.0.0/0 (for direct service access)
- Custom TCP (8080) - 0.0.0.0/0 (API Gateway)
- Custom TCP (3306) - 0.0.0.0/0 (MySQL - for testing only)
- Custom TCP (6379) - 0.0.0.0/0 (Redis - for testing only)

Outbound Rules:
- All traffic (0.0.0.0/0)
```

## Step 2: Connect and Setup Environment

### SSH Connection
```bash
ssh -i your-key.pem ec2-user@your-instance-public-ip
```

### Update System
```bash
sudo yum update -y
sudo yum install -y git docker curl wget vim htop httpd-tools
```

### Start Docker Service
```bash
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ec2-user

# IMPORTANT: You must logout and login again for group changes to take effect
# OR restart the Docker daemon to apply group changes immediately
sudo systemctl restart docker

# Alternative: Start a new shell session
newgrp docker
```

### Install Docker Compose (Correct Method)
```bash
# Method 1: Install Docker Compose using pip (Recommended)
sudo yum install -y python3-pip
sudo pip3 install docker-compose

# Method 2: Install Docker Compose using curl (Alternative)
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Verify installation
docker-compose --version
```

### Install Additional Tools
```bash
sudo yum install -y curl wget vim htop httpd-tools jq
```

## Step 3: Clone and Setup Project

### Clone Repository
```bash
git clone https://github.com/vpodugu/ecommerce-devops-platform.git
cd ecommerce-devops-platform
```

### Create Environment Files
```bash
# Create .env file for docker-compose
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
EOF
```

## Step 4: Build and Start Services

### Option A: Using Docker Compose (Recommended for Development)

#### Build All Services
```bash
# Build all Docker images
docker-compose build

# Verify images are created
docker images
```

#### Start All Services
```bash
# Start all services
docker-compose up -d

# Check service status
docker-compose ps

# View logs
docker-compose logs -f
```

### Option B: Manual Docker Container Deployment (Production-like)

This approach gives you full control over each container and mimics production deployment scenarios.

#### Step 4B.1: Create Docker Network
```bash
# Create a custom network for inter-service communication
docker network create ecommerce-network

# Verify network creation
docker network ls
docker network inspect ecommerce-network
```

#### Step 4B.2: Start Database Containers

```bash
# Start User Service Database
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

# Start Product Service Database
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

# Start Order Service Database
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

# Start Redis Cache
docker run -d \
  --name ecommerce_redis \
  --network ecommerce-network \
  -e REDIS_PASSWORD=redis_password \
  -p 6379:6379 \
  -v redis_data:/data \
  --restart unless-stopped \
  redis:7-alpine redis-server --requirepass redis_password
```

#### Step 4B.3: Wait for Databases to Initialize
```bash
# Wait for databases to be ready
echo "Waiting for databases to initialize..."
sleep 30

# Verify database containers are running
docker ps | grep mysql
docker ps | grep redis

# Test database connections
docker exec ecommerce_user_db mysql -u root -prootpassword -e "SELECT 1;" 2>/dev/null && echo "✅ User DB Ready" || echo "❌ User DB Not Ready"
docker exec ecommerce_product_db mysql -u root -prootpassword -e "SELECT 1;" 2>/dev/null && echo "✅ Product DB Ready" || echo "❌ Product DB Not Ready"
docker exec ecommerce_order_db mysql -u root -prootpassword -e "SELECT 1;" 2>/dev/null && echo "✅ Order DB Ready" || echo "❌ Order DB Not Ready"
```

#### Step 4B.4: Build Microservice Images
```bash
# Build User Service
docker build -t ecommerce/user-service:latest ./services/user-service/

# Build Product Service
docker build -t ecommerce/product-service:latest ./services/product-service/

# Build Order Service
docker build -t ecommerce/order-service:latest ./services/order-service/

# Build API Gateway
docker build -t ecommerce/api-gateway:latest ./services/api-gateway/

# Build Frontend
docker build -t ecommerce/frontend:latest ./frontend/

# Verify all images are built
docker images | grep ecommerce
```

#### Step 4B.5: Start Microservice Containers

```bash
# Start User Service
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

# Start Product Service
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

# Start Order Service
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

# Start API Gateway
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

# Start Frontend
docker run -d \
  --name ecommerce-frontend \
  --network ecommerce-network \
  -p 80:80 \
  -e REACT_APP_API_URL=http://localhost:8080 \
  --restart unless-stopped \
  ecommerce/frontend:latest
```

#### Step 4B.6: Verify All Containers Are Running
```bash
# Check all containers status
docker ps

# Check container logs for any errors
docker logs ecommerce-user-service
docker logs ecommerce-product-service
docker logs ecommerce-order-service
docker logs ecommerce-api-gateway
docker logs ecommerce-frontend

# Check network connectivity
docker network inspect ecommerce-network
```

#### Step 4B.7: Health Check All Services
```bash
# Test health endpoints
echo "Testing service health..."

# User Service
curl -s http://localhost:3001/health | jq . || echo "User Service not responding"

# Product Service
curl -s http://localhost:3002/health | jq . || echo "Product Service not responding"

# Order Service
curl -s http://localhost:3003/health | jq . || echo "Order Service not responding"

# API Gateway
curl -s http://localhost:8080/health | jq . || echo "API Gateway not responding"

# Frontend (should return HTML)
curl -s -I http://localhost:80 | head -1 || echo "Frontend not responding"
```

#### Step 4B.8: Manual Container Management Commands

```bash
# View real-time logs
docker logs -f ecommerce-user-service &
docker logs -f ecommerce-product-service &
docker logs -f ecommerce-order-service &
docker logs -f ecommerce-api-gateway &

# Stop specific service
docker stop ecommerce-user-service

# Start specific service
docker start ecommerce-user-service

# Restart specific service
docker restart ecommerce-user-service

# Remove specific container
docker rm -f ecommerce-user-service

# Update specific service (pull new image and restart)
docker pull ecommerce/user-service:latest
docker stop ecommerce-user-service
docker rm ecommerce-user-service
# Then run the docker run command again for user-service

# Scale specific service (run multiple instances)
docker run -d --name ecommerce-user-service-2 --network ecommerce-network -p 3004:3001 [other-options] ecommerce/user-service:latest
```

#### Step 4B.9: Cleanup Manual Deployment
```bash
# Stop all containers
docker stop ecommerce-user-service ecommerce-product-service ecommerce-order-service ecommerce-api-gateway ecommerce-frontend
docker stop ecommerce_user_db ecommerce_product_db ecommerce_order_db ecommerce_redis

# Remove all containers
docker rm ecommerce-user-service ecommerce-product-service ecommerce-order-service ecommerce-api-gateway ecommerce-frontend
docker rm ecommerce_user_db ecommerce_product_db ecommerce_order_db ecommerce_redis

# Remove volumes (WARNING: This will delete all data)
docker volume rm user_db_data product_db_data order_db_data redis_data

# Remove network
docker network rm ecommerce-network

# Remove images
docker rmi ecommerce/user-service:latest ecommerce/product-service:latest ecommerce/order-service:latest ecommerce/api-gateway:latest ecommerce/frontend:latest
```

## Step 5: Understanding Deployment Methods

### Docker Compose vs Manual Deployment

#### When to Use Docker Compose:
- **Development environments** - Quick setup and teardown
- **Testing scenarios** - Consistent environment across team
- **Simple deployments** - When you need all services or nothing
- **Learning and experimentation** - Easy to understand and modify
- **CI/CD pipelines** - Automated testing environments

#### When to Use Manual Docker Deployment:
- **Production environments** - Fine-grained control over each service
- **Microservices architecture** - Independent scaling and updates
- **Complex networking** - Custom network configurations
- **Resource optimization** - Specific resource allocation per container
- **Service isolation** - Independent lifecycle management
- **Learning Docker fundamentals** - Understanding underlying commands

#### Key Differences:

| Aspect | Docker Compose | Manual Docker |
|--------|----------------|---------------|
| **Setup** | Single `docker-compose up` | Multiple `docker run` commands |
| **Configuration** | YAML file | Command-line arguments |
| **Networking** | Automatic network creation | Manual network setup |
| **Service Discovery** | Automatic via service names | Manual hostname configuration |
| **Scaling** | `docker-compose up --scale` | Manual container replication |
| **Updates** | `docker-compose up --build` | Manual stop/remove/run cycle |
| **Debugging** | `docker-compose logs` | Individual `docker logs` |
| **Resource Control** | Limited in compose file | Full Docker run options |

## Step 6: Verify Service Health

### Check Individual Service Health
```bash
# User Service
curl http://localhost:3001/health

# Product Service
curl http://localhost:3002/health

# Order Service
curl http://localhost:3003/health

# API Gateway
curl http://localhost:8080/health
```

### Check Database Connections
```bash
# Connect to User Service DB
docker exec -it ecommerce_user_db mysql -u root -prootpassword -e "USE user_service; SHOW TABLES;"

# Connect to Product Service DB
docker exec -it ecommerce_product_db mysql -u root -prootpassword -e "USE product_service; SHOW TABLES;"

# Connect to Order Service DB
docker exec -it ecommerce_order_db mysql -u root -prootpassword -e "USE order_service; SHOW TABLES;"
```

## Step 7: API Testing

### Test User Service APIs
```bash
# Get all users
curl http://localhost:8080/api/users

# Register a new user
curl -X POST http://localhost:8080/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123",
    "first_name": "Test",
    "last_name": "User"
  }'

# Login
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123"
  }'
```

### Test Product Service APIs
```bash
# Get all products
curl http://localhost:8080/api/products

# Get products with pagination
curl "http://localhost:8080/api/products?page=1&limit=5"

# Get products by category
curl "http://localhost:8080/api/products?category=1"

# Get featured products
curl "http://localhost:8080/api/products?featured=true"

# Get single product
curl http://localhost:8080/api/products/1

# Get categories
curl http://localhost:8080/api/categories

# Get inventory for product
curl http://localhost:8080/api/inventory/1
```

### Test Order Service APIs
```bash
# Get all orders
curl http://localhost:8080/api/orders

# Get cart items
curl http://localhost:8080/api/cart

# Add item to cart
curl -X POST http://localhost:8080/api/cart \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": 1,
    "product_id": 1,
    "quantity": 2
  }'
```

## Step 8: Cross-Service Integration Testing

### Test Complete User Journey
```bash
# 1. Register user
USER_RESPONSE=$(curl -s -X POST http://localhost:8080/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "customer@example.com",
    "password": "password123",
    "first_name": "John",
    "last_name": "Doe"
  }')
echo "User Registration: $USER_RESPONSE"

# 2. Login and get token
LOGIN_RESPONSE=$(curl -s -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "customer@example.com",
    "password": "password123"
  }')
TOKEN=$(echo $LOGIN_RESPONSE | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
echo "Login Token: $TOKEN"

# 3. Browse products
PRODUCTS=$(curl -s http://localhost:8080/api/products?limit=3)
echo "Products: $PRODUCTS"

# 4. Get product details
PRODUCT_DETAIL=$(curl -s http://localhost:8080/api/products/1)
echo "Product Detail: $PRODUCT_DETAIL"

# 5. Check inventory
INVENTORY=$(curl -s http://localhost:8080/api/inventory/1)
echo "Inventory: $INVENTORY"
```

## Step 9: Performance and Load Testing

### Basic Load Test
```bash
# Install Apache Bench if not available
sudo yum install -y httpd-tools

# Test API Gateway performance
ab -n 100 -c 10 http://localhost:8080/api/products

# Test individual service performance
ab -n 100 -c 10 http://localhost:3001/health
ab -n 100 -c 10 http://localhost:3002/health
ab -n 100 -c 10 http://localhost:3003/health
```

### Database Performance Test
```bash
# Test database connection performance
for i in {1..10}; do
  curl -s http://localhost:3001/health | grep -o '"database":"[^"]*"'
  sleep 1
done
```

## Step 10: Monitoring and Logs

### View Service Logs
```bash
# View all logs
docker-compose logs

# View specific service logs
docker-compose logs user-service
docker-compose logs product-service
docker-compose logs order-service
docker-compose logs api-gateway

# Follow logs in real-time
docker-compose logs -f
```

### Monitor Resource Usage
```bash
# Check container resource usage
docker stats

# Check disk usage
df -h

# Check memory usage
free -h

# Check CPU usage
top
```

### Check Network Connectivity
```bash
# Test inter-service communication
docker exec ecommerce-user-service curl -s http://product-service:3002/health
docker exec ecommerce-order-service curl -s http://user-service:3001/health
docker exec ecommerce-api-gateway curl -s http://user-service:3001/health
```

## Step 11: Troubleshooting

### Common Issues and Solutions

#### Service Won't Start
```bash
# Check if ports are already in use
sudo netstat -tulpn | grep :300

# Check Docker daemon status
sudo systemctl status docker

# Check available disk space
df -h
```

#### Database Connection Issues
```bash
# Check if databases are running
docker ps | grep mysql

# Check database logs
docker logs ecommerce_user_db
docker logs ecommerce_product_db
docker logs ecommerce_order_db

# Test database connectivity
docker exec ecommerce_user_db mysql -u root -prootpassword -e "SELECT 1;"
```

#### API Gateway Issues
```bash
# Check if all services are reachable
curl http://localhost:3001/health
curl http://localhost:3002/health
curl http://localhost:3003/health

# Check API Gateway logs
docker logs ecommerce-api-gateway
```

#### Docker Compose Issues
```bash
# If docker-compose command not found, install it:
sudo pip3 install docker-compose

# Or use the standalone version:
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Verify installation
docker-compose --version
```

#### Docker Permission Issues
```bash
# If you get "permission denied" error:
# Option 1: Restart Docker daemon (recommended)
sudo systemctl restart docker

# Option 2: Start new shell session with docker group
newgrp docker

# Option 3: Logout and login again
exit
# Then SSH back in

# Option 4: Use sudo (temporary workaround)
sudo docker-compose build

# Verify Docker access
docker ps
```

## Step 12: Cleanup and Documentation

### Document Test Results
```bash
# Create test report
cat > test-report.md << EOF
# Phase 1 Manual Testing Report

## Test Date: $(date)

## Services Tested:
- [ ] User Service (Port 3001)
- [ ] Product Service (Port 3002)
- [ ] Order Service (Port 3003)
- [ ] API Gateway (Port 8080)

## Database Status:
- [ ] User Service DB
- [ ] Product Service DB
- [ ] Order Service DB
- [ ] Redis Cache

## API Endpoints Tested:
- [ ] User Registration/Login
- [ ] Product Catalog
- [ ] Inventory Management
- [ ] Order Processing

## Performance Metrics:
- Response Time: ___ ms
- Throughput: ___ requests/sec
- Error Rate: ___ %

## Issues Found:
- None / List issues here

## Recommendations:
- List recommendations here
EOF
```

### Cleanup (Optional)
```bash
# Stop all services
docker-compose down

# Remove all containers and volumes
docker-compose down -v

# Remove all images
docker rmi $(docker images -q)

# Clean up system
sudo yum clean all
```

## Success Criteria

### ✅ All Services Running
- All 4 microservices start successfully
- All 3 databases initialize with sample data
- Redis cache is operational

### ✅ API Functionality
- User registration and authentication works
- Product catalog browsing works
- Inventory management works
- Order processing works
- API Gateway routes requests correctly

### ✅ Cross-Service Communication
- Order service can call User service
- Order service can call Product service
- API Gateway can proxy to all services

### ✅ Performance
- Response times under 500ms for most requests
- No memory leaks or resource exhaustion
- Stable under basic load testing

### ✅ Monitoring
- Health checks return 200 OK
- Logs are properly formatted and accessible
- Resource usage is reasonable

## Next Steps

Once manual testing is successful:

1. **Document any issues found**
2. **Optimize based on test results**
3. **Proceed to Phase 2: GitHub Actions CI/CD**
4. **Implement automated testing**
5. **Set up monitoring and alerting**

This manual testing validates our microservices architecture and ensures we have a solid foundation before implementing automated DevOps processes.
