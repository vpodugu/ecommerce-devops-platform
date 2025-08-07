const express = require('express');
const router = express.Router();
const { body, param, validationResult } = require('express-validator');
const database = require('../config/database');
const logger = require('../utils/logger');

/**
 * @swagger
 * /api/categories:
 *   get:
 *     summary: Get all categories
 *     tags: [Categories]
 *     responses:
 *       200:
 *         description: List of categories
 */
router.get('/', async (req, res) => {
  try {
    const query = `
      SELECT 
        c.*,
        COUNT(p.id) as product_count,
        pc.name as parent_category_name
      FROM categories c
      LEFT JOIN products p ON c.id = p.category_id AND p.is_active = TRUE
      LEFT JOIN categories pc ON c.parent_category_id = pc.id
      WHERE c.is_active = TRUE
      GROUP BY c.id
      ORDER BY c.name
    `;
    
    const categories = await database.query(query);
    res.json({ categories });
  } catch (error) {
    logger.error('Error fetching categories:', error);
    res.status(500).json({ error: 'Failed to fetch categories' });
  }
});

/**
 * @swagger
 * /api/categories/{id}:
 *   get:
 *     summary: Get category by ID
 *     tags: [Categories]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *     responses:
 *       200:
 *         description: Category details
 *       404:
 *         description: Category not found
 */
router.get('/:id', [
  param('id').isInt({ min: 1 }).withMessage('Category ID must be a positive integer')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const categoryId = req.params.id;
    
    const query = `
      SELECT 
        c.*,
        COUNT(p.id) as product_count,
        pc.name as parent_category_name
      FROM categories c
      LEFT JOIN products p ON c.id = p.category_id AND p.is_active = TRUE
      LEFT JOIN categories pc ON c.parent_category_id = pc.id
      WHERE c.id = ? AND c.is_active = TRUE
      GROUP BY c.id
    `;
    
    const categories = await database.query(query, [categoryId]);
    
    if (categories.length === 0) {
      return res.status(404).json({ error: 'Category not found' });
    }
    
    res.json(categories[0]);
  } catch (error) {
    logger.error('Error fetching category:', error);
    res.status(500).json({ error: 'Failed to fetch category' });
  }
});

/**
 * @swagger
 * /api/categories:
 *   post:
 *     summary: Create a new category
 *     tags: [Categories]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - name
 *             properties:
 *               name:
 *                 type: string
 *               description:
 *                 type: string
 *               parent_category_id:
 *                 type: integer
 *     responses:
 *       201:
 *         description: Category created successfully
 */
router.post('/', [
  body('name').notEmpty().trim().withMessage('Category name is required'),
  body('description').optional().isString().trim().withMessage('Description must be a string'),
  body('parent_category_id').optional().isInt({ min: 1 }).withMessage('Parent category ID must be a positive integer')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { name, description, parent_category_id } = req.body;

    // Check if category name already exists
    const nameCheck = await database.query('SELECT id FROM categories WHERE name = ? AND is_active = TRUE', [name]);
    if (nameCheck.length > 0) {
      return res.status(400).json({ error: 'Category name already exists' });
    }

    // Check if parent category exists
    if (parent_category_id) {
      const parentCheck = await database.query('SELECT id FROM categories WHERE id = ? AND is_active = TRUE', [parent_category_id]);
      if (parentCheck.length === 0) {
        return res.status(400).json({ error: 'Invalid parent category ID' });
      }
    }

    const insertQuery = `
      INSERT INTO categories (name, description, parent_category_id)
      VALUES (?, ?, ?)
    `;

    const result = await database.query(insertQuery, [name, description, parent_category_id]);
    
    logger.info(`Category created with ID: ${result.insertId}`);

    res.status(201).json({
      message: 'Category created successfully',
      category_id: result.insertId
    });
  } catch (error) {
    logger.error('Error creating category:', error);
    res.status(500).json({ error: 'Failed to create category' });
  }
});

module.exports = router;
