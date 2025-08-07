-- Order Service Database Initialization
-- This script creates the database schema for order processing and management

USE order_service;

-- Orders table
CREATE TABLE IF NOT EXISTS orders (
    id INT AUTO_INCREMENT PRIMARY KEY,
    order_number VARCHAR(50) UNIQUE NOT NULL,
    user_id INT NOT NULL,
    status ENUM('pending', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled', 'refunded') DEFAULT 'pending',
    total_amount DECIMAL(10,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',
    payment_status ENUM('pending', 'completed', 'failed', 'refunded') DEFAULT 'pending',
    payment_method VARCHAR(50),
    payment_transaction_id VARCHAR(255),
    shipping_address JSON,
    billing_address JSON,
    shipping_method VARCHAR(100),
    shipping_cost DECIMAL(8,2) DEFAULT 0.00,
    tracking_number VARCHAR(100),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_order_number (order_number),
    INDEX idx_user_id (user_id),
    INDEX idx_status (status),
    INDEX idx_payment_status (payment_status),
    INDEX idx_created_at (created_at)
);

-- Order items table
CREATE TABLE IF NOT EXISTS order_items (
    id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    product_name VARCHAR(255) NOT NULL,
    product_sku VARCHAR(100),
    quantity INT NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    total_price DECIMAL(10,2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
    INDEX idx_order_id (order_id),
    INDEX idx_product_id (product_id)
);

-- Order status history table
CREATE TABLE IF NOT EXISTS order_status_history (
    id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    status ENUM('pending', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled', 'refunded') NOT NULL,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
    INDEX idx_order_id (order_id),
    INDEX idx_status (status),
    INDEX idx_created_at (created_at)
);

-- Shopping cart table (for Redis backup)
CREATE TABLE IF NOT EXISTS shopping_carts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY unique_user_product (user_id, product_id),
    INDEX idx_user_id (user_id),
    INDEX idx_product_id (product_id)
);

-- Insert sample orders
INSERT INTO orders (order_number, user_id, status, total_amount, payment_status, shipping_address, billing_address) VALUES
('ORD-2024-001', 1, 'delivered', 1029.98, 'completed', 
 '{"street": "123 Main St", "city": "New York", "state": "NY", "zip_code": "10001", "country": "USA"}',
 '{"street": "123 Main St", "city": "New York", "state": "NY", "zip_code": "10001", "country": "USA"}'),
('ORD-2024-002', 2, 'processing', 89.98, 'completed',
 '{"street": "456 Oak Ave", "city": "Los Angeles", "state": "CA", "zip_code": "90210", "country": "USA"}',
 '{"street": "456 Oak Ave", "city": "Los Angeles", "state": "CA", "zip_code": "90210", "country": "USA"}')
ON DUPLICATE KEY UPDATE updated_at = CURRENT_TIMESTAMP;

-- Insert sample order items
INSERT INTO order_items (order_id, product_id, product_name, product_sku, quantity, unit_price, total_price) VALUES
(1, 1, 'iPhone 15 Pro', 'IPHONE-15-PRO', 1, 999.99, 999.99),
(1, 3, 'Men\'s Casual T-Shirt', 'TSHIRT-MEN-001', 1, 29.99, 29.99),
(2, 4, 'Women\'s Summer Dress', 'DRESS-WOMEN-001', 1, 59.99, 59.99),
(2, 5, 'The Great Gatsby', 'BOOK-FICTION-001', 1, 12.99, 12.99),
(2, 6, 'Python Programming Guide', 'BOOK-NONFICTION-001', 1, 16.99, 16.99)
ON DUPLICATE KEY UPDATE updated_at = CURRENT_TIMESTAMP;

-- Insert sample order status history
INSERT INTO order_status_history (order_id, status, notes) VALUES
(1, 'pending', 'Order created'),
(1, 'confirmed', 'Payment received'),
(1, 'processing', 'Order being prepared'),
(1, 'shipped', 'Order shipped via FedEx'),
(1, 'delivered', 'Order delivered successfully'),
(2, 'pending', 'Order created'),
(2, 'confirmed', 'Payment received'),
(2, 'processing', 'Order being prepared')
ON DUPLICATE KEY UPDATE created_at = CURRENT_TIMESTAMP;
