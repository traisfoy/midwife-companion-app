// Midwife-facing API: caseload, patient detail, thresholds, alerts, location.
import { Router } from 'express';
import { query } from '../db.js';
import { requireAuth, requireRole } from '../middleware/auth.js';
import { analyzeContractionPattern } from '../services/alertEngine.js';
import { estimateDriveTime, geocodeAddress } from '../services/mapping.js';
import { emitToMidwife } from '../services/realtime.js';

const router = Router();
router.use(requireAuth, requireRole('midwife'));

// Verify a patient belongs to this midwife before exposing their data.
async function ownedPatient(midwifeId, patientId) {
  const { rows } = await query(
    'SELECT * FROM patients WHERE id = $1 AND midwife_id = $2',
    [patientId, midwifeId]
  );
  return rows[0] || null;
}

// Caseload: all active patients with live pattern stats; alerting patients first.
router.get('/caseload', async (req, res) => {
  const { rows: patients } = await query(
    `SELECT p.id, p.name, p.phone, p.address, p.due_date, p.lat, p.lng,
            p.threshold_frequency_minutes, p.threshold_duration_seconds,
            p.threshold_pattern_minutes, p.intake_reminder_minutes,
            (SELECT max(start_time) FROM contraction_logs c WHERE c.patient_id = p.id) AS last_contraction_at,
            (SELECT max(logged_at) FROM intake_logs i WHERE i.patient_id = p.id AND i.type = 'water') AS last_water_at,
            (SELECT max(logged_at) FROM intake_logs i WHERE i.patient_id = p.id AND i.type = 'food') AS last_food_at,
            (SELECT row_to_json(a) FROM (
               SELECT id, triggered_at, pattern_detected, eta_seconds, eta_source
               FROM alerts WHERE patient_id = p.id AND acknowledged = FALSE
               ORDER BY triggered_at DESC LIMIT 1
             ) a) AS active_alert
     FROM patients p
     WHERE p.midwife_id = $1 AND p.active
     ORDER BY p.due_date ASC`,
    [req.user.id]
  );

  const caseload = await Promise.all(
    patients.map(async (p) => ({
      ...p,
      pattern: await analyzeContractionPattern({
        id: p.id,
        threshold_frequency_minutes: p.threshold_frequency_minutes,
        threshold_duration_seconds: p.threshold_duration_seconds,
        threshold_pattern_minutes: p.threshold_pattern_minutes,
      }),
    }))
  );

  // Alerting patients pinned to the top, then by due date (already sorted).
  caseload.sort((a, b) => (b.active_alert ? 1 : 0) - (a.active_alert ? 1 : 0));
  res.json({ caseload });
});

// Per-patient detail: contractions, intake, medication adherence, alerts.
router.get('/patients/:id', async (req, res) => {
  const patient = await ownedPatient(req.user.id, req.params.id);
  if (!patient) return res.status(404).json({ error: 'Patient not found' });

  const [contractions, intake, reminders, alerts, pattern] = await Promise.all([
    query(
      `SELECT * FROM contraction_logs
       WHERE patient_id = $1 AND start_time >= now() - interval '24 hours'
       ORDER BY start_time ASC`,
      [patient.id]
    ),
    query(
      `SELECT * FROM intake_logs
       WHERE patient_id = $1 AND logged_at >= now() - interval '72 hours'
       ORDER BY logged_at DESC`,
      [patient.id]
    ),
    query(
      `SELECT r.*,
              (SELECT max(logged_at) FROM intake_logs il
               WHERE il.patient_id = r.patient_id AND il.type = 'medication'
                 AND il.description ILIKE r.name) AS last_logged_at
       FROM medication_reminders r
       WHERE r.patient_id = $1 AND r.active`,
      [patient.id]
    ),
    query(
      `SELECT * FROM alerts WHERE patient_id = $1
       ORDER BY triggered_at DESC LIMIT 20`,
      [patient.id]
    ),
    analyzeContractionPattern(patient),
  ]);

  const { password_hash, ...safePatient } = patient;
  res.json({
    patient: safePatient,
    contractions: contractions.rows,
    intake: intake.rows,
    medicationReminders: reminders.rows,
    alerts: alerts.rows,
    pattern,
  });
});

// Per-patient alert threshold + reminder window configuration.
router.patch('/patients/:id/thresholds', async (req, res) => {
  const patient = await ownedPatient(req.user.id, req.params.id);
  if (!patient) return res.status(404).json({ error: 'Patient not found' });

  const fields = {
    threshold_frequency_minutes: req.body.frequencyMinutes,
    threshold_duration_seconds: req.body.durationSeconds,
    threshold_pattern_minutes: req.body.patternMinutes,
    intake_reminder_minutes: req.body.intakeReminderMinutes,
  };
  const updates = [];
  const values = [];
  for (const [col, val] of Object.entries(fields)) {
    if (val == null) continue;
    const n = parseInt(val, 10);
    if (!Number.isFinite(n) || n <= 0) {
      return res.status(400).json({ error: `${col} must be a positive integer` });
    }
    values.push(n);
    updates.push(`${col} = $${values.length}`);
  }
  if (updates.length === 0) {
    return res.status(400).json({ error: 'No threshold fields provided' });
  }
  values.push(patient.id);
  const { rows } = await query(
    `UPDATE patients SET ${updates.join(', ')} WHERE id = $${values.length} RETURNING
       id, threshold_frequency_minutes, threshold_duration_seconds,
       threshold_pattern_minutes, intake_reminder_minutes`,
    values
  );
  res.json({ patient: rows[0] });
});

// Update the midwife's current location (from browser geolocation or manual entry).
router.patch('/location', async (req, res) => {
  const lat = parseFloat(req.body.lat);
  const lng = parseFloat(req.body.lng);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
    return res.status(400).json({ error: 'lat and lng are required numbers' });
  }
  const { rows } = await query(
    `UPDATE midwives SET lat = $1, lng = $2, location_updated_at = now()
     WHERE id = $3 RETURNING lat, lng, location_updated_at`,
    [lat, lng, req.user.id]
  );
  res.json({ location: rows[0] });
});

// Alerts panel.
router.get('/alerts', async (req, res) => {
  const onlyOpen = req.query.unacknowledged === '1';
  const { rows } = await query(
    `SELECT a.*, p.name AS patient_name, p.address AS patient_address
     FROM alerts a JOIN patients p ON p.id = a.patient_id
     WHERE p.midwife_id = $1 ${onlyOpen ? 'AND a.acknowledged = FALSE' : ''}
     ORDER BY a.acknowledged ASC, a.triggered_at DESC
     LIMIT 50`,
    [req.user.id]
  );
  res.json({ alerts: rows });
});

// One-tap acknowledge.
router.post('/alerts/:id/acknowledge', async (req, res) => {
  const { rows } = await query(
    `UPDATE alerts a SET acknowledged = TRUE, acknowledged_at = now()
     FROM patients p
     WHERE a.id = $1 AND p.id = a.patient_id AND p.midwife_id = $2
     RETURNING a.*`,
    [req.params.id, req.user.id]
  );
  if (rows.length === 0) return res.status(404).json({ error: 'Alert not found' });
  emitToMidwife(req.user.id, 'alert:acknowledged', rows[0]);
  res.json({ alert: rows[0] });
});

// Refresh the drive-time estimate for an open alert (e.g. after moving).
router.post('/alerts/:id/refresh-eta', async (req, res) => {
  const { rows } = await query(
    `SELECT a.id, p.lat AS plat, p.lng AS plng, m.lat AS mlat, m.lng AS mlng
     FROM alerts a
     JOIN patients p ON p.id = a.patient_id
     JOIN midwives m ON m.id = p.midwife_id
     WHERE a.id = $1 AND p.midwife_id = $2`,
    [req.params.id, req.user.id]
  );
  const row = rows[0];
  if (!row) return res.status(404).json({ error: 'Alert not found' });
  const eta = await estimateDriveTime(
    { lat: row.mlat, lng: row.mlng },
    { lat: row.plat, lng: row.plng }
  );
  const { rows: updated } = await query(
    `UPDATE alerts SET eta_seconds = $1, eta_source = $2 WHERE id = $3 RETURNING *`,
    [eta?.seconds ?? null, eta?.source ?? 'unavailable', row.id]
  );
  res.json({ alert: updated[0] });
});

// Re-geocode a patient's address (used when editing; requires ORS key).
router.post('/patients/:id/geocode', async (req, res) => {
  const patient = await ownedPatient(req.user.id, req.params.id);
  if (!patient) return res.status(404).json({ error: 'Patient not found' });
  const coords = await geocodeAddress(patient.address);
  if (!coords) {
    return res.status(422).json({
      error: 'Geocoding unavailable (no ORS_API_KEY configured or address not found)',
    });
  }
  const { rows } = await query(
    'UPDATE patients SET lat = $1, lng = $2 WHERE id = $3 RETURNING id, lat, lng',
    [coords.lat, coords.lng, patient.id]
  );
  res.json({ patient: rows[0] });
});

export default router;
