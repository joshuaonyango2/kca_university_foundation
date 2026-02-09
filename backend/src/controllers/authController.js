const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const pool = require('../config/database');
const { validationResult } = require('express-validator');

class AuthController {
  /**
   * Register new user
   */
  async register(req, res) {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ 
          success: false, 
          errors: errors.array() 
        });
      }

      const {
        email,
        phone_number,
        password,
        first_name,
        last_name,
        organization,
        is_corporate
      } = req.body;

      // Check if user exists
      const existingUser = await pool.query(
        'SELECT user_id FROM users WHERE email = $1 OR phone_number = $2',
        [email, phone_number]
      );

      if (existingUser.rows.length > 0) {
        return res.status(409).json({
          success: false,
          message: 'User with this email or phone number already exists'
        });
      }

      // Hash password
      const salt = await bcrypt.genSalt(10);
      const password_hash = await bcrypt.hash(password, salt);

      // Insert user
      const result = await pool.query(
        `INSERT INTO users (
          email, phone_number, password_hash, first_name, last_name, 
          organization, is_corporate, role
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        RETURNING user_id, email, phone_number, first_name, last_name, role, created_at`,
        [
          email,
          phone_number,
          password_hash,
          first_name,
          last_name,
          organization || null,
          is_corporate || false,
          'donor'
        ]
      );

      const user = result.rows[0];

      // Generate JWT
      const token = jwt.sign(
        { 
          user_id: user.user_id, 
          email: user.email,
          role: user.role 
        },
        process.env.JWT_SECRET,
        { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
      );

      res.status(201).json({
        success: true,
        message: 'Registration successful',
        data: {
          user: {
            user_id: user.user_id,
            email: user.email,
            phone_number: user.phone_number,
            first_name: user.first_name,
            last_name: user.last_name,
            role: user.role
          },
          token
        }
      });
    } catch (error) {
      console.error('Registration error:', error);
      res.status(500).json({
        success: false,
        message: 'Server error during registration'
      });
    }
  }

  /**
   * Login user
   */
  async login(req, res) {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ 
          success: false, 
          errors: errors.array() 
        });
      }

      const { email, password } = req.body;

      // Find user
      const result = await pool.query(
        `SELECT user_id, email, phone_number, password_hash, first_name, 
                last_name, role, status, email_verified, phone_verified
         FROM users 
         WHERE email = $1 AND status = 'active'`,
        [email]
      );

      if (result.rows.length === 0) {
        return res.status(401).json({
          success: false,
          message: 'Invalid email or password'
        });
      }

      const user = result.rows[0];

      // Verify password
      const isValidPassword = await bcrypt.compare(password, user.password_hash);
      if (!isValidPassword) {
        return res.status(401).json({
          success: false,
          message: 'Invalid email or password'
        });
      }

      // Generate JWT
      const token = jwt.sign(
        { 
          user_id: user.user_id, 
          email: user.email,
          role: user.role 
        },
        process.env.JWT_SECRET,
        { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
      );

      // Update last login
      await pool.query(
        'UPDATE users SET last_login = CURRENT_TIMESTAMP WHERE user_id = $1',
        [user.user_id]
      );

      // Remove password_hash from response
      delete user.password_hash;

      res.json({
        success: true,
        message: 'Login successful',
        data: {
          user,
          token
        }
      });
    } catch (error) {
      console.error('Login error:', error);
      res.status(500).json({
        success: false,
        message: 'Server error during login'
      });
    }
  }

  /**
   * Get current user profile
   */
  async getProfile(req, res) {
    try {
      const result = await pool.query(
        `SELECT user_id, email, phone_number, first_name, last_name, 
                organization, is_corporate, role, profile_image_url,
                email_verified, phone_verified, created_at
         FROM users 
         WHERE user_id = $1`,
        [req.user.user_id]
      );

      if (result.rows.length === 0) {
        return res.status(404).json({
          success: false,
          message: 'User not found'
        });
      }

      res.json({
        success: true,
        data: result.rows[0]
      });
    } catch (error) {
      console.error('Get profile error:', error);
      res.status(500).json({
        success: false,
        message: 'Server error'
      });
    }
  }

  /**
   * Update user profile
   */
  async updateProfile(req, res) {
    try {
      const { first_name, last_name, phone_number, organization } = req.body;

      const result = await pool.query(
        `UPDATE users 
         SET first_name = COALESCE($1, first_name),
             last_name = COALESCE($2, last_name),
             phone_number = COALESCE($3, phone_number),
             organization = COALESCE($4, organization),
             updated_at = CURRENT_TIMESTAMP
         WHERE user_id = $5
         RETURNING user_id, email, phone_number, first_name, last_name, organization`,
        [first_name, last_name, phone_number, organization, req.user.user_id]
      );

      res.json({
        success: true,
        message: 'Profile updated successfully',
        data: result.rows[0]
      });
    } catch (error) {
      console.error('Update profile error:', error);
      res.status(500).json({
        success: false,
        message: 'Server error'
      });
    }
  }
}

module.exports = new AuthController();