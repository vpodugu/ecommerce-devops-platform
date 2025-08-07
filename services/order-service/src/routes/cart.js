const express = require('express');
const database = require('../config/database');
const logger = require('../utils/logger');

const router = express.Router();

router.get('/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    
    const result = await database.query(
      `SELECT c.*, p.name, p.price, p.image_url 
       FROM cart_items c 
       LEFT JOIN products p ON c.product_id = p.id 
       WHERE c.user_id = ?`,
      [userId]
    );

    const totalResult = await database.query(
      `SELECT SUM(c.quantity * p.price) as total 
       FROM cart_items c 
       LEFT JOIN products p ON c.product_id = p.id 
       WHERE c.user_id = ?`,
      [userId]
    );

    res.json({
      items: result,
      total: totalResult[0]?.total || 0,
      count: result.length
    });
  } catch (error) {
    logger.error('Cart fetch error:', error);
    res.status(500).json({
      error: 'Failed to fetch cart',
      message: 'Internal server error'
    });
  }
});

router.post('/', async (req, res) => {
  try {
    const { user_id, product_id, quantity } = req.body;

    if (!user_id || !product_id || !quantity) {
      return res.status(400).json({
        error: 'Missing required fields',
        required: ['user_id', 'product_id', 'quantity']
      });
    }

    const existingResult = await database.query(
      'SELECT * FROM cart_items WHERE user_id = ? AND product_id = ?',
      [user_id, product_id]
    );

    if (existingResult.length > 0) {
      await database.query(
        'UPDATE cart_items SET quantity = quantity + ?, updated_at = NOW() WHERE user_id = ? AND product_id = ?',
        [quantity, user_id, product_id]
      );
    } else {
      await database.query(
        'INSERT INTO cart_items (user_id, product_id, quantity, created_at) VALUES (?, ?, ?, NOW())',
        [user_id, product_id, quantity]
      );
    }

    res.status(201).json({
      message: 'Item added to cart successfully'
    });
  } catch (error) {
    logger.error('Cart add error:', error);
    res.status(500).json({
      error: 'Failed to add item to cart',
      message: 'Internal server error'
    });
  }
});

router.put('/:userId/:productId', async (req, res) => {
  try {
    const { userId, productId } = req.params;
    const { quantity } = req.body;

    if (!quantity || quantity < 1) {
      return res.status(400).json({
        error: 'Invalid quantity',
        message: 'Quantity must be at least 1'
      });
    }

    const result = await database.query(
      'UPDATE cart_items SET quantity = ?, updated_at = NOW() WHERE user_id = ? AND product_id = ?',
      [quantity, userId, productId]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({
        error: 'Cart item not found'
      });
    }

    res.json({
      message: 'Cart item updated successfully'
    });
  } catch (error) {
    logger.error('Cart update error:', error);
    res.status(500).json({
      error: 'Failed to update cart item',
      message: 'Internal server error'
    });
  }
});

router.delete('/:userId/:productId', async (req, res) => {
  try {
    const { userId, productId } = req.params;

    const result = await database.query(
      'DELETE FROM cart_items WHERE user_id = ? AND product_id = ?',
      [userId, productId]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({
        error: 'Cart item not found'
      });
    }

    res.json({
      message: 'Item removed from cart successfully'
    });
  } catch (error) {
    logger.error('Cart delete error:', error);
    res.status(500).json({
      error: 'Failed to remove cart item',
      message: 'Internal server error'
    });
  }
});

router.delete('/:userId', async (req, res) => {
  try {
    const { userId } = req.params;

    await database.query(
      'DELETE FROM cart_items WHERE user_id = ?',
      [userId]
    );

    res.json({
      message: 'Cart cleared successfully'
    });
  } catch (error) {
    logger.error('Cart clear error:', error);
    res.status(500).json({
      error: 'Failed to clear cart',
      message: 'Internal server error'
    });
  }
});

module.exports = router;