-- Product Service Database Initialization
-- This script creates the database schema for product catalog management

USE product_service;

-- Categories table
CREATE TABLE IF NOT EXISTS categories (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    parent_category_id INT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (parent_category_id) REFERENCES categories(id) ON DELETE SET NULL,
    INDEX idx_name (name),
    INDEX idx_parent_category (parent_category_id),
    INDEX idx_is_active (is_active)
);

-- Products table
CREATE TABLE IF NOT EXISTS products (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price DECIMAL(10,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',
    category_id INT NOT NULL,
    sku VARCHAR(100) UNIQUE,
    barcode VARCHAR(100),
    weight DECIMAL(8,2),
    dimensions VARCHAR(100),
    is_active BOOLEAN DEFAULT TRUE,
    is_featured BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (category_id) REFERENCES categories(id),
    INDEX idx_name (name),
    INDEX idx_category_id (category_id),
    INDEX idx_sku (sku),
    INDEX idx_price (price),
    INDEX idx_is_active (is_active),
    INDEX idx_is_featured (is_featured),
    FULLTEXT idx_search (name, description)
);

-- Product images table
CREATE TABLE IF NOT EXISTS product_images (
    id INT AUTO_INCREMENT PRIMARY KEY,
    product_id INT NOT NULL,
    image_url VARCHAR(500) NOT NULL,
    alt_text VARCHAR(255),
    is_primary BOOLEAN DEFAULT FALSE,
    sort_order INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    INDEX idx_product_id (product_id),
    INDEX idx_is_primary (is_primary),
    INDEX idx_sort_order (sort_order)
);

-- Inventory table
CREATE TABLE IF NOT EXISTS inventory (
    id INT AUTO_INCREMENT PRIMARY KEY,
    product_id INT NOT NULL,
    quantity INT NOT NULL DEFAULT 0,
    reserved_quantity INT NOT NULL DEFAULT 0,
    low_stock_threshold INT DEFAULT 10,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    UNIQUE KEY unique_product (product_id),
    INDEX idx_quantity (quantity),
    INDEX idx_low_stock (quantity, low_stock_threshold)
);

-- Product specifications table
CREATE TABLE IF NOT EXISTS product_specifications (
    id INT AUTO_INCREMENT PRIMARY KEY,
    product_id INT NOT NULL,
    spec_name VARCHAR(100) NOT NULL,
    spec_value TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    INDEX idx_product_id (product_id),
    INDEX idx_spec_name (spec_name)
);

-- Product tags table
CREATE TABLE IF NOT EXISTS product_tags (
    id INT AUTO_INCREMENT PRIMARY KEY,
    product_id INT NOT NULL,
    tag_name VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    INDEX idx_product_id (product_id),
    INDEX idx_tag_name (tag_name)
);

-- Insert sample categories
INSERT INTO categories (name, description) VALUES
('Electronics', 'Electronic devices and accessories'),
('Clothing', 'Apparel and fashion items'),
('Books', 'Books and publications'),
('Home & Garden', 'Home improvement and garden supplies')
ON DUPLICATE KEY UPDATE updated_at = CURRENT_TIMESTAMP;

-- Insert subcategories
INSERT INTO categories (name, description, parent_category_id) VALUES
('Smartphones', 'Mobile phones and accessories', 1),
('Laptops', 'Portable computers', 1),
('Men\'s Clothing', 'Clothing for men', 2),
('Women\'s Clothing', 'Clothing for women', 2),
('Fiction', 'Fiction books', 3),
('Non-Fiction', 'Non-fiction books', 3)
ON DUPLICATE KEY UPDATE updated_at = CURRENT_TIMESTAMP;

-- Insert sample products
INSERT INTO products (name, description, price, category_id, sku, weight, is_featured) VALUES
('iPhone 15 Pro', 'Latest iPhone with advanced camera system', 999.99, 5, 'IPHONE-15-PRO', 0.187, TRUE),
('MacBook Air M2', 'Lightweight laptop with M2 chip', 1199.99, 6, 'MACBOOK-AIR-M2', 1.24, TRUE),
('Men\'s Casual T-Shirt', 'Comfortable cotton t-shirt for everyday wear', 29.99, 7, 'TSHIRT-MEN-001', 0.2, FALSE),
('Women\'s Summer Dress', 'Elegant summer dress with floral pattern', 59.99, 8, 'DRESS-WOMEN-001', 0.3, TRUE),
('The Great Gatsby', 'Classic American novel by F. Scott Fitzgerald', 12.99, 9, 'BOOK-FICTION-001', 0.4, FALSE),
('Python Programming Guide', 'Comprehensive guide to Python programming', 39.99, 10, 'BOOK-NONFICTION-001', 0.8, TRUE)
ON DUPLICATE KEY UPDATE updated_at = CURRENT_TIMESTAMP;

-- Insert product images
INSERT INTO product_images (product_id, image_url, alt_text, is_primary) VALUES
(1, 'https://example.com/images/iphone15pro.jpg', 'iPhone 15 Pro', TRUE),
(1, 'https://example.com/images/iphone15pro-back.jpg', 'iPhone 15 Pro Back', FALSE),
(2, 'https://example.com/images/macbook-air-m2.jpg', 'MacBook Air M2', TRUE),
(3, 'https://example.com/images/mens-tshirt.jpg', 'Men\'s Casual T-Shirt', TRUE),
(4, 'https://example.com/images/womens-dress.jpg', 'Women\'s Summer Dress', TRUE),
(5, 'https://example.com/images/great-gatsby.jpg', 'The Great Gatsby Book', TRUE),
(6, 'https://example.com/images/python-guide.jpg', 'Python Programming Guide', TRUE)
ON DUPLICATE KEY UPDATE updated_at = CURRENT_TIMESTAMP;

-- Insert inventory
INSERT INTO inventory (product_id, quantity, low_stock_threshold) VALUES
(1, 50, 10),
(2, 25, 5),
(3, 100, 20),
(4, 75, 15),
(5, 200, 30),
(6, 150, 25)
ON DUPLICATE KEY UPDATE updated_at = CURRENT_TIMESTAMP;

-- Insert product specifications
INSERT INTO product_specifications (product_id, spec_name, spec_value) VALUES
(1, 'Screen Size', '6.1 inches'),
(1, 'Storage', '128GB'),
(1, 'Color', 'Natural Titanium'),
(2, 'Processor', 'M2 Chip'),
(2, 'Memory', '8GB Unified Memory'),
(2, 'Storage', '256GB SSD'),
(3, 'Material', '100% Cotton'),
(3, 'Size', 'M, L, XL'),
(4, 'Material', 'Polyester Blend'),
(4, 'Size', 'XS, S, M, L, XL')
ON DUPLICATE KEY UPDATE spec_value = VALUES(spec_value);

-- Insert product tags
INSERT INTO product_tags (product_id, tag_name) VALUES
(1, 'smartphone'),
(1, 'apple'),
(1, '5g'),
(2, 'laptop'),
(2, 'apple'),
(2, 'm2'),
(3, 'clothing'),
(3, 'men'),
(3, 'casual'),
(4, 'clothing'),
(4, 'women'),
(4, 'dress'),
(5, 'book'),
(5, 'fiction'),
(5, 'classic'),
(6, 'book'),
(6, 'programming'),
(6, 'python')
ON DUPLICATE KEY UPDATE tag_name = VALUES(tag_name);
