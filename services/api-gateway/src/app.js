const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const swaggerJsdoc = require('swagger-jsdoc');
const swaggerUi = require('swagger-ui-express');
const { createProxyMiddleware } = require('http-proxy-middleware');
require('dotenv').config();

const logger = require('./utils/logger');
const healthRoutes = require('./routes/health');

const app = express();
const PORT = process.env.PORT || 8080;

// Security middleware
app.use(helmet());
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:3000'],
  credentials: true
}));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 300, // limit each IP to 300 requests per windowMs
  message: 'Too many requests from this IP, please try again later.'
});
app.use('/api/', limiter);

// Body parsing middleware
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Request logging middleware
app.use((req, res, next) => {
  logger.info(`${req.method} ${req.path} - ${req.ip}`);
  next();
});

// Swagger configuration
const swaggerOptions = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: 'E-Commerce API Gateway',
      version: '1.0.0',
      description: 'API Gateway for e-commerce microservices',
    },
    servers: [
      {
        url: `http://localhost:${PORT}`,
        description: 'Development server',
      },
    ],
  },
  apis: ['./src/routes/*.js'],
};

const swaggerSpec = swaggerJsdoc(swaggerOptions);
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec));

// Health check endpoint
app.use('/health', healthRoutes);

// Proxy middleware for microservices
const userServiceProxy = createProxyMiddleware({
  target: process.env.USER_SERVICE_URL || 'http://user-service:3001',
  changeOrigin: true,
  pathRewrite: {
    '^/api/users': '/api/users',
    '^/api/auth': '/api/auth'
  },
  onError: (err, req, res) => {
    logger.error('User Service Proxy Error:', err);
    res.status(503).json({ error: 'User service unavailable' });
  }
});

const productServiceProxy = createProxyMiddleware({
  target: process.env.PRODUCT_SERVICE_URL || 'http://product-service:3002',
  changeOrigin: true,
  pathRewrite: {
    '^/api/products': '/api/products',
    '^/api/categories': '/api/categories',
    '^/api/inventory': '/api/inventory'
  },
  onError: (err, req, res) => {
    logger.error('Product Service Proxy Error:', err);
    res.status(503).json({ error: 'Product service unavailable' });
  }
});

const orderServiceProxy = createProxyMiddleware({
  target: process.env.ORDER_SERVICE_URL || 'http://order-service:3003',
  changeOrigin: true,
  pathRewrite: {
    '^/api/orders': '/api/orders',
    '^/api/cart': '/api/cart'
  },
  onError: (err, req, res) => {
    logger.error('Order Service Proxy Error:', err);
    res.status(503).json({ error: 'Order service unavailable' });
  }
});

// Route proxying
app.use('/api/users', userServiceProxy);
app.use('/api/auth', userServiceProxy);
app.use('/api/products', productServiceProxy);
app.use('/api/categories', productServiceProxy);
app.use('/api/inventory', productServiceProxy);
app.use('/api/orders', orderServiceProxy);
app.use('/api/cart', orderServiceProxy);

// Root endpoint
app.get('/', (req, res) => {
  res.json({
    service: 'API Gateway',
    version: '1.0.0',
    status: 'running',
    timestamp: new Date().toISOString(),
    endpoints: {
      health: '/health',
      users: '/api/users',
      auth: '/api/auth',
      products: '/api/products',
      categories: '/api/categories',
      inventory: '/api/inventory',
      orders: '/api/orders',
      cart: '/api/cart',
      docs: '/api-docs'
    },
    services: {
      user_service: process.env.USER_SERVICE_URL || 'http://user-service:3001',
      product_service: process.env.PRODUCT_SERVICE_URL || 'http://product-service:3002',
      order_service: process.env.ORDER_SERVICE_URL || 'http://order-service:3003'
    }
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    error: 'Endpoint not found',
    path: req.originalUrl,
    method: req.method
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  logger.error('Unhandled error:', err);
  
  res.status(500).json({
    error: 'Internal Server Error',
    message: process.env.NODE_ENV === 'development' ? err.message : 'Something went wrong'
  });
});

// Start server
app.listen(PORT, () => {
  logger.info(`API Gateway running on port ${PORT}`);
  logger.info(`API Documentation available at http://localhost:${PORT}/api-docs`);
  logger.info(`Health check available at http://localhost:${PORT}/health`);
});

module.exports = app;
