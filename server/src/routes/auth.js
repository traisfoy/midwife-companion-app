import { Router } from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { query } from '../db.js';
import { config } from '../config.js';
import { requireAuth } from '../middleware/auth.js';

const router = Router();

// Single login endpoint for both roles: midwife accounts are checked first,
// then patient accounts. No role hierarchy beyond that for the MVP.
router.post('/login', async (req, res) => {
  const { email, password } = req.body || {};
  if (!email || !password) {
    return res.status(400).json({ error: 'Email and password are required' });
  }

  const lookups = [
    { role: 'midwife', sql: 'SELECT * FROM midwives WHERE lower(email) = lower($1)' },
    { role: 'patient', sql: 'SELECT * FROM patients WHERE lower(email) = lower($1)' },
  ];

  for (const { role, sql } of lookups) {
    const { rows } = await query(sql, [email]);
    const user = rows[0];
    if (user && bcrypt.compareSync(password, user.password_hash)) {
      const token = jwt.sign(
        { id: user.id, role, name: user.name },
        config.jwtSecret,
        { expiresIn: '7d' }
      );
      return res.json({
        token,
        user: { id: user.id, role, name: user.name, email: user.email },
      });
    }
  }
  res.status(401).json({ error: 'Invalid email or password' });
});

router.get('/me', requireAuth, (req, res) => {
  res.json({ user: req.user });
});

export default router;
