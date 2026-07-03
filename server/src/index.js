/*
 * Midwife Companion — API server.
 *
 * ⚠️  PRODUCTION / COMPLIANCE NOTE:
 * This is a prototype. Before real patient data touches this system, a HIPAA
 * risk assessment must be completed and signed BAAs (Business Associate
 * Agreements) must be in place with every third-party service in the data
 * path (hosting, database, mapping/geocoding provider, push notification
 * relays, etc.). Current auth is standard email/password with bcrypt hashes
 * over HTTPS — adequate for a demo, not for PHI.
 */
import http from 'node:http';
import express from 'express';
import cors from 'cors';
import { config } from './config.js';
import { pool } from './db.js';
import authRoutes from './routes/auth.js';
import patientRoutes from './routes/patient.js';
import midwifeRoutes from './routes/midwife.js';
import pushRoutes from './routes/push.js';
import { initRealtime } from './services/realtime.js';
import { startReminderJobs } from './services/reminders.js';

const app = express();
app.use(cors({ origin: true, credentials: true }));
app.use(express.json());

app.get('/api/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ ok: true });
  } catch (err) {
    res.status(503).json({ ok: false, error: err.message });
  }
});

app.use('/api/auth', authRoutes);
app.use('/api/patient', patientRoutes);
app.use('/api/midwife', midwifeRoutes);
app.use('/api/push', pushRoutes);

// Route-level async errors land here.
app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({ error: 'Internal server error' });
});

const server = http.createServer(app);
initRealtime(server);

server.listen(config.port, () => {
  console.log(`API listening on http://localhost:${config.port}`);
  startReminderJobs();
});
