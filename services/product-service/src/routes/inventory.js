const express = require('express');
const router = express.Router();
const { body, param, validationResult } = require('express-validator');
const database = require('../config/database');
const logger = require('../utils/logger');

/**
 * @swagger
 * /api/inventory/{productId}:
 *   get:
 *     summary: Get inventory for a product
 *     tags: [Inventory]
 *     parameters:
 *       - in: path
 *         name: productId
 *         required: true
 *         schema:
 *           type: integer
 *     responses:
 *       200:
 *         description: Inventory details
 *       404:
 *         description: Product not found
 */
router.get('/:productId', [
  param('productId').isInt({ min: 1 }).withMessage('Product ID must be a positive integer')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const productId = req.params.productId;

    const query = `
      SELECT 
        i.*,
        p.name as product_name,
        p.sku
      FROM inventory i
      JOIN products p ON i.product_id = p.id
      WHERE i.product_id = ? AND p.is_active = TRUE
    `;

    const inventory = await database.query(query, [productId]);

    if (inventory.length === 0) {
      return res.status(404).json({ error: 'Product not found' });
    }

    const result = {
      ...inventory[0],
      available_quantity: inventory[0].quantity - inventory[0].reserved_quantity,
      is_low_stock: inventory[0].quantity <= inventory[0].low_stock_threshold
    };

    res.json(result);
  } catch (error) {
    logger.error('Error fetching inventory:', error);
    res.status(500).json({ error: 'Failed to fetch inventory' });
  }
});

/**
 * @swagger
 * /api/inventory/{productId}:
 *   put:
 *     summary: Update inventory for a product
 *     tags: [Inventory]
 *     parameters:
 *       - in: path
 *         name: productId
 *         required: true
 *         schema:
 *           type: integer
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               quantity:
 *                 type: integer
 *               reserved_quantity:
 *                 type: integer
 *               low_stock_threshold:
 *                 type: integer
 *     responses:
 *       200:
 *         description: Inventory updated successfully
 *       404:
 *         description: Product not found
 */
router.put('/:productId', [
  param('productId').isInt({ min: 1 }).withMessage('Product ID must be a positive integer'),
  body('quantity').optional().isInt({ min: 0 }).withMessage('Quantity must be a non-negative integer'),
  body('reserved_quantity').optional().isInt({ min: 0 }).withMessage('Reserved quantity must be a non-negative integer'),
  body('low_stock_threshold').optional().isInt({ min: 0 }).withMessage('Low stock threshold must be a non-negative integer')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const productId = req.params.productId;
    const updateData = req.body;

    // Check if product exists
    const productCheck = await database.query('SELECT id FROM products WHERE id = ? AND is_active = TRUE', [productId]);
    if (productCheck.length === 0) {
      return res.status(404).json({ error: 'Product not found' });
    }

    // Build update query dynamically
    const updateFields = [];
    const updateValues = [];

    Object.keys(updateData).forEach(key => {
      if (['quantity', 'reserved_quantity', 'low_stock_threshold'].includes(key)) {
        updateFields.push(`${key} = ?`);
        updateValues.push(updateData[key]);
      }
    });

    if (updateFields.length === 0) {
      return res.status(400).json({ error: 'No valid fields to update' });
    }

    updateFields.push('updated_at = CURRENT_TIMESTAMP');
    updateValues.push(productId);

    const updateQuery = `UPDATE inventory SET ${updateFields.join(', ')} WHERE product_id = ?`;
    await database.query(updateQuery, updateValues);

    logger.info(`Inventory updated for product ID: ${productId}`);

    res.json({ message: 'Inventory updated successfully' });
  } catch (error) {
    logger.error('Error updating inventory:', error);
    res.status(500).json({ error: 'Failed to update inventory' });
  }
});

/**
 * @swagger
 * /api/inventory/{productId}/reserve:
 *   post:
 *     summary: Reserve inventory for a product
 *     tags: [Inventory]
 *     parameters:
 *       - in: path
 *         name: productId
 *         required: true
 *         schema:
 *           type: integer
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - quantity
 *             properties:
 *               quantity:
 *                 type: integer
 *     responses:
 *       200:
 *         description: Inventory reserved successfully
 *       400:
 *         description: Insufficient inventory
 *       404:
 *         description: Product not found
 */
router.post('/:productId/reserve', [
  param('productId').isInt({ min: 1 }).withMessage('Product ID must be a positive integer'),
  body('quantity').isInt({ min: 1 }).withMessage('Quantity must be a positive integer')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const productId = req.params.productId;
    const { quantity } = req.body;

    // Use transaction to ensure data consistency
    await database.transaction(async (connection) => {
      // Get current inventory
      const [inventory] = await connection.execute(
        'SELECT quantity, reserved_quantity FROM inventory WHERE product_id = ? FOR UPDATE',
        [productId]
      );

      if (inventory.length === 0) {
        throw new Error('Product not found');
      }

      const currentInventory = inventory[0];
      const availableQuantity = currentInventory.quantity - currentInventory.reserved_quantity;

      if (availableQuantity < quantity) {
        throw new Error('Insufficient inventory');
      }

      // Reserve the quantity
      await connection.execute(
        'UPDATE inventory SET reserved_quantity = reserved_quantity + ?, updated_at = CURRENT_TIMESTAMP WHERE product_id = ?',
        [quantity, productId]
      );
    });

    logger.info(`Reserved ${quantity} units for product ID: ${productId}`);

    res.json({ 
      message: 'Inventory reserved successfully',
      reserved_quantity: quantity
    });
  } catch (error) {
    logger.error('Error reserving inventory:', error);
    
    if (error.message === 'Product not found') {
      return res.status(404).json({ error: 'Product not found' });
    }
    
    if (error.message === 'Insufficient inventory') {
      return res.status(400).json({ error: 'Insufficient inventory' });
    }
    
    res.status(500).json({ error: 'Failed to reserve inventory' });
  }
});

/**
 * @swagger
 * /api/inventory/{productId}/release:
 *   post:
 *     summary: Release reserved inventory for a product
 *     tags: [Inventory]
 *     parameters:
 *       - in: path
 *         name: productId
 *         required: true
 *         schema:
 *           type: integer
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - quantity
 *             properties:
 *               quantity:
 *                 type: integer
 *     responses:
 *       200:
 *         description: Inventory released successfully
 *       400:
 *         description: Invalid quantity
 *       404:
 *         description: Product not found
 */
router.post('/:productId/release', [
  param('productId').isInt({ min: 1 }).withMessage('Product ID must be a positive integer'),
  body('quantity').isInt({ min: 1 }).withMessage('Quantity must be a positive integer')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const productId = req.params.productId;
    const { quantity } = req.body;

    // Use transaction to ensure data consistency
    await database.transaction(async (connection) => {
      // Get current inventory
      const [inventory] = await connection.execute(
        'SELECT reserved_quantity FROM inventory WHERE product_id = ? FOR UPDATE',
        [productId]
      );

      if (inventory.length === 0) {
        throw new Error('Product not found');
      }

      const currentReserved = inventory[0].reserved_quantity;

      if (currentReserved < quantity) {
        throw new Error('Cannot release more than reserved quantity');
      }

      // Release the quantity
      await connection.execute(
        'UPDATE inventory SET reserved_quantity = reserved_quantity - ?, updated_at = CURRENT_TIMESTAMP WHERE product_id = ?',
        [quantity, productId]
      );
    });

    logger.info(`Released ${quantity} units for product ID: ${productId}`);

    res.json({ 
      message: 'Inventory released successfully',
      released_quantity: quantity
    });
  } catch (error) {
    logger.error('Error releasing inventory:', error);
    
    if (error.message === 'Product not found') {
      return res.status(404).json({ error: 'Product not found' });
    }
    
    if (error.message === 'Cannot release more than reserved quantity') {
      return res.status(400).json({ error: 'Cannot release more than reserved quantity' });
    }
    
    res.status(500).json({ error: 'Failed to release inventory' });
  }
});

module.exports = router;
