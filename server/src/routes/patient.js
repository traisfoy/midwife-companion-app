// Patient-facing API: contraction timer, intake logging, medication reminders.
import { Router } from 'express';
import { query } from '../db.js';
import { requireAuth, requireRole } from '../middleware/auth.js';
import { evaluatePatientAfterContraction } from '../services/alertEngine.js';
import { emitToMidwife } from '../services/realtime.js';

const router = Router();
router.use(requireAuth, requireRole('patient'));

async function getPatient(id) {
  const { rows } = await query(
    `SELECT p.*, m.name AS midwife_name, m.practice_name
     FROM patients p LEFT JOIN midwives m ON m.id = p.midwife_id
     WHERE p.id = $1`,
    [id]
  );
  return rows[0];
}

router.get('/me', async (req, res) => {
  const p = await getPatient(req.user.id);
  if (!p) return res.status(404).json({ error: 'Patient not found' });
  const { password_hash, ...safe } = p;
  res.json({ patient: safe });
});

// --- Contractions ---

router.get('/contractions', async (req, res) => {
  const hours = Math.min(parseInt(req.query.hours || '24', 10), 24 * 7);
  const { rows } = await query(
    `SELECT * FROM contraction_logs
     WHERE patient_id = $1 AND start_time >= now() - make_interval(hours => $2)
     ORDER BY start_time DESC`,
    [req.user.id, hours]
  );
  res.json({ contractions: rows });
});

// The timer posts a completed contraction (start + stop captured client-side).
router.post('/contractions', async (req, res) => {
  const { startTime, endTime } = req.body || {};
  const start = new Date(startTime);
  const end = new Date(endTime);
  if (isNaN(start) || isNaN(end) || end <= start) {
    return res.status(400).json({ error: 'startTime and endTime (ISO, end after start) are required' });
  }
  if (end - start > 15 * 60 * 1000) {
    return res.status(400).json({ error: 'Contraction longer than 15 minutes — was the timer left running?' });
  }

  const { rows } = await query(
    `INSERT INTO contraction_logs (patient_id, start_time, end_time)
     VALUES ($1, $2, $3) RETURNING *`,
    [req.user.id, start.toISOString(), end.toISOString()]
  );
  const log = rows[0];

  const patient = await getPatient(req.user.id);
  if (patient?.midwife_id) {
    emitToMidwife(patient.midwife_id, 'contraction:new', {
      ...log,
      patient_name: patient.name,
    });
  }

  // Core alert logic: evaluate the pattern on every new contraction log.
  const alert = await evaluatePatientAfterContraction(req.user.id);

  res.status(201).json({ contraction: log, alert });
});

// --- Intake (water / food / medication) ---

router.get('/intake', async (req, res) => {
  const hours = Math.min(parseInt(req.query.hours || '48', 10), 24 * 14);
  const { rows } = await query(
    `SELECT * FROM intake_logs
     WHERE patient_id = $1 AND logged_at >= now() - make_interval(hours => $2)
     ORDER BY logged_at DESC`,
    [req.user.id, hours]
  );
  res.json({ intake: rows });
});

router.post('/intake', async (req, res) => {
  const { type, amount, description } = req.body || {};
  if (!['water', 'food', 'medication'].includes(type)) {
    return res.status(400).json({ error: 'type must be water, food, or medication' });
  }
  if (type === 'water' && !amount) {
    return res.status(400).json({ error: 'amount is required for water' });
  }
  if (type !== 'water' && !description) {
    return res.status(400).json({ error: 'description is required' });
  }

  const { rows } = await query(
    `INSERT INTO intake_logs (patient_id, type, amount, description)
     VALUES ($1, $2, $3, $4) RETURNING *`,
    [req.user.id, type, amount || null, description || null]
  );
  const log = rows[0];

  const patient = await getPatient(req.user.id);
  if (patient?.midwife_id) {
    emitToMidwife(patient.midwife_id, 'intake:new', {
      ...log,
      patient_name: patient.name,
    });
  }
  res.status(201).json({ intake: log });
});

// --- Medication reminders ---

router.get('/medication-reminders', async (req, res) => {
  const { rows } = await query(
    `SELECT * FROM medication_reminders
     WHERE patient_id = $1 AND active ORDER BY next_due_at ASC`,
    [req.user.id]
  );
  res.json({ reminders: rows });
});

router.post('/medication-reminders', async (req, res) => {
  const { name, dose, intervalHours, firstDueAt } = req.body || {};
  const interval = parseFloat(intervalHours);
  if (!name || !interval || interval <= 0) {
    return res.status(400).json({ error: 'name and a positive intervalHours are required' });
  }
  const firstDue = firstDueAt
    ? new Date(firstDueAt)
    : new Date(Date.now() + interval * 3600 * 1000);
  if (isNaN(firstDue)) {
    return res.status(400).json({ error: 'firstDueAt must be a valid timestamp' });
  }
  const { rows } = await query(
    `INSERT INTO medication_reminders (patient_id, name, dose, interval_hours, next_due_at)
     VALUES ($1, $2, $3, $4, $5) RETURNING *`,
    [req.user.id, name, dose || null, interval, firstDue.toISOString()]
  );
  res.status(201).json({ reminder: rows[0] });
});

router.delete('/medication-reminders/:id', async (req, res) => {
  await query(
    'UPDATE medication_reminders SET active = FALSE WHERE id = $1 AND patient_id = $2',
    [req.params.id, req.user.id]
  );
  res.json({ ok: true });
});

export default router;
