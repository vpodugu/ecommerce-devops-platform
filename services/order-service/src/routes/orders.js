const express = require('express');
const database = require('../config/database');
const logger = require('../utils/logger');

const router = express.Router();

router.get('/', async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 10;
    const offset = (page - 1) * limit;

    const result = await database.query(
      'SELECT * FROM orders ORDER BY created_at DESC LIMIT ? OFFSET ?',
      [limit, offset]
    );

    const countResult = await database.query('SELECT COUNT(*) as count FROM orders');
    const total = parseInt(countResult[0].count);

    res.json({
      orders: result,
      pagination: {
        page,
        limit,
        total,
        pages: Math.ceil(total / limit)
      }
    });
  } catch (error) {
    logger.error('Orders fetch error:', error);
    res.status(500).json({
      error: 'Failed to fetch orders',
      message: 'Internal server error'
    });
  }
});

router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await database.query(
      'SELECT * FROM orders WHERE id = ?',
      [id]
    );

    if (result.length === 0) {
      return res.status(404).json({
        error: 'Order not found'
      });
    }

    const order = result[0];
    
    const itemsResult = await database.query(
      'SELECT * FROM order_items WHERE order_id = ?',
      [id]
    );

    res.json({
      order: {
        ...order,
        items: itemsResult
      }
    });
  } catch (error) {
    logger.error('Order fetch error:', error);
    res.status(500).json({
      error: 'Failed to fetch order',
      message: 'Internal server error'
    });
  }
});

router.post('/', async (req, res) => {
  try {
    const { user_id, items, total_amount, shipping_address } = req.body;

    if (!user_id || !items || !items.length || !total_amount) {
      return res.status(400).json({
        error: 'Missing required fields',
        required: ['user_id', 'items', 'total_amount']
      });
    }

    const orderResult = await database.query(
      'INSERT INTO orders (user_id, total_amount, status, shipping_address, created_at) VALUES (?, ?, ?, ?, NOW())',
      [user_id, total_amount, 'pending', JSON.stringify(shipping_address)]
    );

    const orderId = orderResult.insertId;

    for (const item of items) {
      await database.query(
        'INSERT INTO order_items (order_id, product_id, quantity, price) VALUES (?, ?, ?, ?)',
        [orderId, item.product_id, item.quantity, item.price]
      );
    }

    const newOrderResult = await database.query(
      'SELECT * FROM orders WHERE id = ?',
      [orderId]
    );

    res.status(201).json({
      message: 'Order created successfully',
      order: newOrderResult[0]
    });
  } catch (error) {
    logger.error('Order creation error:', error);
    res.status(500).json({
      error: 'Failed to create order',
      message: 'Internal server error'
    });
  }
});

router.patch('/:id/status', async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;

    const validStatuses = ['pending', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled'];
    if (!validStatuses.includes(status)) {
      return res.status(400).json({
        error: 'Invalid status',
        validStatuses
      });
    }

    const result = await database.query(
      'UPDATE orders SET status = ?, updated_at = NOW() WHERE id = ?',
      [status, id]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({
        error: 'Order not found'
      });
    }

    const updatedOrderResult = await database.query(
      'SELECT * FROM orders WHERE id = ?',
      [id]
    );

    res.json({
      message: 'Order status updated successfully',
      order: updatedOrderResult[0]
    });
  } catch (error) {
    logger.error('Order status update error:', error);
    res.status(500).json({
      error: 'Failed to update order status',
      message: 'Internal server error'
    });
  }
});

module.exports = router;