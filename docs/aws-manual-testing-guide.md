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
sudo yum install -y git docker docker-compose-plugin
```

### Start Docker Service
```bash
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ec2-user
# Logout and login again for group changes to take effect
```

### Install Additional Tools
```bash
sudo yum install -y curl wget vim htop
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

### Build All Services
```bash
# Build all Docker images
docker-compose build

# Verify images are created
docker images
```

### Start All Services
```bash
# Start all services
docker-compose up -d

# Check service status
docker-compose ps

# View logs
docker-compose logs -f
```

## Step 5: Verify Service Health

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

## Step 6: API Testing

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

## Step 7: Cross-Service Integration Testing

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

## Step 8: Performance and Load Testing

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

## Step 9: Monitoring and Logs

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

## Step 10: Troubleshooting

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

## Step 11: Cleanup and Documentation

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
