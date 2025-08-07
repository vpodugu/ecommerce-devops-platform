const mysql = require('mysql2/promise');
const logger = require('../utils/logger');

class Database {
  constructor() {
    this.pool = null;
  }

  async connect() {
    try {
      this.pool = mysql.createPool({
        host: process.env.DB_HOST || 'user_db',
        port: process.env.DB_PORT || 3306,
        user: process.env.DB_USER || 'user_service',
        password: process.env.DB_PASSWORD || 'user_service_pass',
        database: process.env.DB_NAME || 'user_service',
        waitForConnections: true,
        connectionLimit: 10,
        queueLimit: 0,
        acquireTimeout: 60000,
        timeout: 60000,
        reconnect: true
      });

      logger.info('Database pool created successfully');
    } catch (error) {
      logger.error('Failed to create database pool:', error);
      throw error;
    }
  }

  async testConnection() {
    try {
      if (!this.pool) {
        await this.connect();
      }
      
      const connection = await this.pool.getConnection();
      await connection.ping();
      connection.release();
      
      logger.info('Database connection test successful');
    } catch (error) {
      logger.error('Database connection test failed:', error);
      throw error;
    }
  }

  async query(sql, params = []) {
    try {
      if (!this.pool) {
        await this.connect();
      }
      
      const [rows] = await this.pool.execute(sql, params);
      return rows;
    } catch (error) {
      logger.error('Database query error:', error);
      throw error;
    }
  }

  async transaction(callback) {
    if (!this.pool) {
      await this.connect();
    }
    
    const connection = await this.pool.getConnection();
    await connection.beginTransaction();
    
    try {
      const result = await callback(connection);
      await connection.commit();
      return result;
    } catch (error) {
      await connection.rollback();
      throw error;
    } finally {
      connection.release();
    }
  }

  async closeConnection() {
    if (this.pool) {
      await this.pool.end();
      logger.info('Database connection closed');
    }
  }
}

module.exports = new Database();
