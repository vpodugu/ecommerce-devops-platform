const express = require('express');
const router = express.Router();
const { body, query, param, validationResult } = require('express-validator');
const database = require('../config/database');
const logger = require('../utils/logger');

/**
 * @swagger
 * components:
 *   schemas:
 *     Product:
 *       type: object
 *       required:
 *         - name
 *         - price
 *         - category_id
 *       properties:
 *         id:
 *           type: integer
 *           description: Product ID
 *         name:
 *           type: string
 *           description: Product name
 *         description:
 *           type: string
 *           description: Product description
 *         price:
 *           type: number
 *           description: Product price
 *         currency:
 *           type: string
 *           description: Currency code
 *         category_id:
 *           type: integer
 *           description: Category ID
 *         sku:
 *           type: string
 *           description: Stock keeping unit
 *         is_active:
 *           type: boolean
 *           description: Product availability
 *         is_featured:
 *           type: boolean
 *           description: Featured product flag
 */

/**
 * @swagger
 * /api/products:
 *   get:
 *     summary: Get all products with pagination and filters
 *     tags: [Products]
 *     parameters:
 *       - in: query
 *         name: page
 *         schema:
 *           type: integer
 *           default: 1
 *         description: Page number
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           default: 10
 *         description: Number of items per page
 *       - in: query
 *         name: category
 *         schema:
 *           type: integer
 *         description: Filter by category ID
 *       - in: query
 *         name: search
 *         schema:
 *           type: string
 *         description: Search in product name and description
 *       - in: query
 *         name: min_price
 *         schema:
 *           type: number
 *         description: Minimum price filter
 *       - in: query
 *         name: max_price
 *         schema:
 *           type: number
 *         description: Maximum price filter
 *       - in: query
 *         name: featured
 *         schema:
 *           type: boolean
 *         description: Filter featured products only
 *     responses:
 *       200:
 *         description: List of products
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 products:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Product'
 *                 pagination:
 *                   type: object
 *                   properties:
 *                     page:
 *                       type: integer
 *                     limit:
 *                       type: integer
 *                     total:
 *                       type: integer
 *                     pages:
 *                       type: integer
 */
router.get('/', [
  query('page').optional().isInt({ min: 1 }).withMessage('Page must be a positive integer'),
  query('limit').optional().isInt({ min: 1, max: 100 }).withMessage('Limit must be between 1 and 100'),
  query('category').optional().isInt({ min: 1 }).withMessage('Category must be a positive integer'),
  query('min_price').optional().isFloat({ min: 0 }).withMessage('Min price must be a positive number'),
  query('max_price').optional().isFloat({ min: 0 }).withMessage('Max price must be a positive number'),
  query('featured').optional().isBoolean().withMessage('Featured must be a boolean')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 10;
    const offset = (page - 1) * limit;
    
    let whereClause = 'WHERE p.is_active = TRUE';
    let params = [];
    let paramIndex = 1;

    // Category filter
    if (req.query.category) {
      whereClause += ` AND p.category_id = ?`;
      params.push(req.query.category);
    }

    // Price filters
    if (req.query.min_price) {
      whereClause += ` AND p.price >= ?`;
      params.push(req.query.min_price);
    }
    if (req.query.max_price) {
      whereClause += ` AND p.price <= ?`;
      params.push(req.query.max_price);
    }

    // Featured filter
    if (req.query.featured === 'true') {
      whereClause += ` AND p.is_featured = TRUE`;
    }

    // Search filter
    if (req.query.search) {
      whereClause += ` AND (p.name LIKE ? OR p.description LIKE ?)`;
      const searchTerm = `%${req.query.search}%`;
      params.push(searchTerm, searchTerm);
    }

    // Get total count
    const countQuery = `
      SELECT COUNT(*) as total 
      FROM products p 
      ${whereClause}
    `;
    const countResult = await database.query(countQuery, params);
    const total = countResult[0].total;

    // Get products with category and images
    const productsQuery = `
      SELECT 
        p.*,
        c.name as category_name,
        GROUP_CONCAT(DISTINCT pi.image_url) as images,
        i.quantity,
        i.low_stock_threshold
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      LEFT JOIN product_images pi ON p.id = pi.product_id
      LEFT JOIN inventory i ON p.id = i.product_id
      ${whereClause}
      GROUP BY p.id
      ORDER BY p.created_at DESC
      LIMIT ? OFFSET ?
    `;
    
    params.push(limit, offset);
    const products = await database.query(productsQuery, params);

    // Process images
    const processedProducts = products.map(product => ({
      ...product,
      images: product.images ? product.images.split(',') : [],
      price: parseFloat(product.price)
    }));

    res.json({
      products: processedProducts,
      pagination: {
        page,
        limit,
        total,
        pages: Math.ceil(total / limit)
      }
    });
  } catch (error) {
    logger.error('Error fetching products:', error);
    res.status(500).json({ error: 'Failed to fetch products' });
  }
});

/**
 * @swagger
 * /api/products/{id}:
 *   get:
 *     summary: Get product by ID
 *     tags: [Products]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: Product ID
 *     responses:
 *       200:
 *         description: Product details
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Product'
 *       404:
 *         description: Product not found
 */
router.get('/:id', [
  param('id').isInt({ min: 1 }).withMessage('Product ID must be a positive integer')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const productId = req.params.id;

    const query = `
      SELECT 
        p.*,
        c.name as category_name,
        GROUP_CONCAT(DISTINCT pi.image_url) as images,
        GROUP_CONCAT(DISTINCT ps.spec_name, ':', ps.spec_value) as specifications,
        GROUP_CONCAT(DISTINCT pt.tag_name) as tags,
        i.quantity,
        i.reserved_quantity,
        i.low_stock_threshold
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      LEFT JOIN product_images pi ON p.id = pi.product_id
      LEFT JOIN product_specifications ps ON p.id = ps.product_id
      LEFT JOIN product_tags pt ON p.id = pt.product_id
      LEFT JOIN inventory i ON p.id = i.product_id
      WHERE p.id = ? AND p.is_active = TRUE
      GROUP BY p.id
    `;

    const products = await database.query(query, [productId]);

    if (products.length === 0) {
      return res.status(404).json({ error: 'Product not found' });
    }

    const product = products[0];

    // Process specifications
    const specifications = {};
    if (product.specifications) {
      product.specifications.split(',').forEach(spec => {
        const [name, value] = spec.split(':');
        specifications[name] = value;
      });
    }

    // Process tags
    const tags = product.tags ? product.tags.split(',') : [];

    // Process images
    const images = product.images ? product.images.split(',') : [];

    const result = {
      ...product,
      price: parseFloat(product.price),
      specifications,
      tags,
      images,
      available_quantity: product.quantity - product.reserved_quantity
    };

    res.json(result);
  } catch (error) {
    logger.error('Error fetching product:', error);
    res.status(500).json({ error: 'Failed to fetch product' });
  }
});

/**
 * @swagger
 * /api/products:
 *   post:
 *     summary: Create a new product
 *     tags: [Products]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - name
 *               - price
 *               - category_id
 *             properties:
 *               name:
 *                 type: string
 *               description:
 *                 type: string
 *               price:
 *                 type: number
 *               category_id:
 *                 type: integer
 *               sku:
 *                 type: string
 *     responses:
 *       201:
 *         description: Product created successfully
 *       400:
 *         description: Validation error
 */
router.post('/', [
  body('name').notEmpty().trim().withMessage('Product name is required'),
  body('price').isFloat({ min: 0 }).withMessage('Price must be a positive number'),
  body('category_id').isInt({ min: 1 }).withMessage('Category ID must be a positive integer'),
  body('sku').optional().isString().trim().withMessage('SKU must be a string'),
  body('description').optional().isString().trim().withMessage('Description must be a string')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { name, description, price, category_id, sku, currency = 'USD' } = req.body;

    // Check if category exists
    const categoryCheck = await database.query('SELECT id FROM categories WHERE id = ? AND is_active = TRUE', [category_id]);
    if (categoryCheck.length === 0) {
      return res.status(400).json({ error: 'Invalid category ID' });
    }

    // Check if SKU is unique
    if (sku) {
      const skuCheck = await database.query('SELECT id FROM products WHERE sku = ?', [sku]);
      if (skuCheck.length > 0) {
        return res.status(400).json({ error: 'SKU already exists' });
      }
    }

    const insertQuery = `
      INSERT INTO products (name, description, price, currency, category_id, sku)
      VALUES (?, ?, ?, ?, ?, ?)
    `;

    const result = await database.query(insertQuery, [name, description, price, currency, category_id, sku]);
    
    // Create inventory record
    await database.query('INSERT INTO inventory (product_id, quantity) VALUES (?, 0)', [result.insertId]);

    logger.info(`Product created with ID: ${result.insertId}`);

    res.status(201).json({
      message: 'Product created successfully',
      product_id: result.insertId
    });
  } catch (error) {
    logger.error('Error creating product:', error);
    res.status(500).json({ error: 'Failed to create product' });
  }
});

/**
 * @swagger
 * /api/products/{id}:
 *   put:
 *     summary: Update a product
 *     tags: [Products]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/Product'
 *     responses:
 *       200:
 *         description: Product updated successfully
 *       404:
 *         description: Product not found
 */
router.put('/:id', [
  param('id').isInt({ min: 1 }).withMessage('Product ID must be a positive integer'),
  body('name').optional().notEmpty().trim().withMessage('Product name cannot be empty'),
  body('price').optional().isFloat({ min: 0 }).withMessage('Price must be a positive number'),
  body('category_id').optional().isInt({ min: 1 }).withMessage('Category ID must be a positive integer')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const productId = req.params.id;
    const updateData = req.body;

    // Check if product exists
    const productCheck = await database.query('SELECT id FROM products WHERE id = ?', [productId]);
    if (productCheck.length === 0) {
      return res.status(404).json({ error: 'Product not found' });
    }

    // Build update query dynamically
    const updateFields = [];
    const updateValues = [];

    Object.keys(updateData).forEach(key => {
      if (['name', 'description', 'price', 'currency', 'category_id', 'sku', 'is_active', 'is_featured'].includes(key)) {
        updateFields.push(`${key} = ?`);
        updateValues.push(updateData[key]);
      }
    });

    if (updateFields.length === 0) {
      return res.status(400).json({ error: 'No valid fields to update' });
    }

    updateFields.push('updated_at = CURRENT_TIMESTAMP');
    updateValues.push(productId);

    const updateQuery = `UPDATE products SET ${updateFields.join(', ')} WHERE id = ?`;
    await database.query(updateQuery, updateValues);

    logger.info(`Product updated with ID: ${productId}`);

    res.json({ message: 'Product updated successfully' });
  } catch (error) {
    logger.error('Error updating product:', error);
    res.status(500).json({ error: 'Failed to update product' });
  }
});

/**
 * @swagger
 * /api/products/{id}:
 *   delete:
 *     summary: Delete a product (soft delete)
 *     tags: [Products]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *     responses:
 *       200:
 *         description: Product deleted successfully
 *       404:
 *         description: Product not found
 */
router.delete('/:id', [
  param('id').isInt({ min: 1 }).withMessage('Product ID must be a positive integer')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const productId = req.params.id;

    // Check if product exists
    const productCheck = await database.query('SELECT id FROM products WHERE id = ?', [productId]);
    if (productCheck.length === 0) {
      return res.status(404).json({ error: 'Product not found' });
    }

    // Soft delete by setting is_active to false
    await database.query('UPDATE products SET is_active = FALSE, updated_at = CURRENT_TIMESTAMP WHERE id = ?', [productId]);

    logger.info(`Product deleted (soft) with ID: ${productId}`);

    res.json({ message: 'Product deleted successfully' });
  } catch (error) {
    logger.error('Error deleting product:', error);
    res.status(500).json({ error: 'Failed to delete product' });
  }
});

module.exports = router;
