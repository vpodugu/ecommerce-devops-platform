const express = require('express');
const jwt = require('jsonwebtoken');
const database = require('../config/database');
const logger = require('../utils/logger');

const router = express.Router();

const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({
      error: 'Access token required'
    });
  }

  jwt.verify(token, process.env.JWT_SECRET || 'fallback_secret', (err, user) => {
    if (err) {
      return res.status(403).json({
        error: 'Invalid or expired token'
      });
    }
    req.user = user;
    next();
  });
};

router.get('/profile', authenticateToken, async (req, res) => {
  try {
    const result = await database.query(
      'SELECT id, username, email, first_name, last_name, created_at, last_login FROM users WHERE id = $1',
      [req.user.userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        error: 'User not found'
      });
    }

    const user = result.rows[0];
    res.json({
      user: {
        id: user.id,
        username: user.username,
        email: user.email,
        firstName: user.first_name,
        lastName: user.last_name,
        createdAt: user.created_at,
        lastLogin: user.last_login
      }
    });
  } catch (error) {
    logger.error('Profile fetch error:', error);
    res.status(500).json({
      error: 'Failed to fetch profile',
      message: 'Internal server error'
    });
  }
});

router.put('/profile', authenticateToken, async (req, res) => {
  try {
    const { firstName, lastName, email } = req.body;
    const updates = {};
    const values = [];
    let paramCount = 1;

    if (firstName !== undefined) {
      updates.first_name = `$${paramCount++}`;
      values.push(firstName);
    }
    if (lastName !== undefined) {
      updates.last_name = `$${paramCount++}`;
      values.push(lastName);
    }
    if (email !== undefined) {
      updates.email = `$${paramCount++}`;
      values.push(email);
    }

    if (Object.keys(updates).length === 0) {
      return res.status(400).json({
        error: 'No fields to update'
      });
    }

    const setClause = Object.entries(updates)
      .map(([key, placeholder]) => `${key} = ${placeholder}`)
      .join(', ');

    values.push(req.user.userId);

    const result = await database.query(
      `UPDATE users SET ${setClause}, updated_at = NOW() WHERE id = $${paramCount} RETURNING id, username, email, first_name, last_name, updated_at`,
      values
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        error: 'User not found'
      });
    }

    const user = result.rows[0];
    res.json({
      message: 'Profile updated successfully',
      user: {
        id: user.id,
        username: user.username,
        email: user.email,
        firstName: user.first_name,
        lastName: user.last_name,
        updatedAt: user.updated_at
      }
    });
  } catch (error) {
    if (error.code === '23505') {
      return res.status(409).json({
        error: 'Email already taken'
      });
    }
    
    logger.error('Profile update error:', error);
    res.status(500).json({
      error: 'Failed to update profile',
      message: 'Internal server error'
    });
  }
});

router.get('/', authenticateToken, async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 10;
    const offset = (page - 1) * limit;

    const result = await database.query(
      'SELECT id, username, email, first_name, last_name, created_at, last_login FROM users ORDER BY created_at DESC LIMIT $1 OFFSET $2',
      [limit, offset]
    );

    const countResult = await database.query('SELECT COUNT(*) FROM users');
    const total = parseInt(countResult.rows[0].count);

    res.json({
      users: result.rows.map(user => ({
        id: user.id,
        username: user.username,
        email: user.email,
        firstName: user.first_name,
        lastName: user.last_name,
        createdAt: user.created_at,
        lastLogin: user.last_login
      })),
      pagination: {
        page,
        limit,
        total,
        pages: Math.ceil(total / limit)
      }
    });
  } catch (error) {
    logger.error('Users fetch error:', error);
    res.status(500).json({
      error: 'Failed to fetch users',
      message: 'Internal server error'
    });
  }
});

module.exports = router;