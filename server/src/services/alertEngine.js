// Alert engine: evaluates a patient's recent contraction pattern against
// their configured threshold (default 5-1-1) every time a contraction is
// logged, and raises an alert + midwife push notification + ETA when crossed.
import { query } from '../db.js';
import { estimateDriveTime, formatEta } from './mapping.js';
import { sendPush } from './push.js';
import { emitToMidwife, emitToPatient } from './realtime.js';

/**
 * Analyze the patient's contraction logs over their configured pattern window
 * (default: last 60 minutes). Returns the computed stats plus whether the
 * pattern crosses the patient's threshold.
 *
 * Threshold semantics (the "5-1-1 rule" with per-patient overrides):
 *   - average gap between contraction STARTS <= threshold_frequency_minutes
 *   - average contraction duration >= threshold_duration_seconds
 *   - the pattern is sustained: logs span most of threshold_pattern_minutes.
 *     "Most of" = window minus one frequency interval, so a patient whose
 *     first contraction of the hour started at minute 3 still qualifies at
 *     the top of the hour instead of needing a log at minute 0 exactly.
 */
export async function analyzeContractionPattern(patient) {
  const windowMinutes = patient.threshold_pattern_minutes;
  const { rows: logs } = await query(
    `SELECT start_time, end_time FROM contraction_logs
     WHERE patient_id = $1
       AND end_time IS NOT NULL
       AND start_time >= now() - make_interval(mins => $2)
     ORDER BY start_time ASC`,
    [patient.id, windowMinutes]
  );

  const threshold = {
    frequencyMinutes: patient.threshold_frequency_minutes,
    durationSeconds: patient.threshold_duration_seconds,
    patternMinutes: patient.threshold_pattern_minutes,
  };

  if (logs.length < 3) {
    return { crossed: false, contractionCount: logs.length, threshold };
  }

  const starts = logs.map((l) => new Date(l.start_time).getTime());
  const gapsMinutes = [];
  for (let i = 1; i < starts.length; i++) {
    gapsMinutes.push((starts[i] - starts[i - 1]) / 60000);
  }
  const avgFrequencyMinutes =
    gapsMinutes.reduce((a, b) => a + b, 0) / gapsMinutes.length;

  const durationsSeconds = logs.map(
    (l) => (new Date(l.end_time).getTime() - new Date(l.start_time).getTime()) / 1000
  );
  const avgDurationSeconds =
    durationsSeconds.reduce((a, b) => a + b, 0) / durationsSeconds.length;

  const spanMinutes = (starts[starts.length - 1] - starts[0]) / 60000;
  const requiredSpanMinutes = Math.max(
    windowMinutes - threshold.frequencyMinutes,
    windowMinutes * 0.5
  );

  const crossed =
    avgFrequencyMinutes <= threshold.frequencyMinutes &&
    avgDurationSeconds >= threshold.durationSeconds &&
    spanMinutes >= requiredSpanMinutes;

  return {
    crossed,
    contractionCount: logs.length,
    avgFrequencyMinutes: Math.round(avgFrequencyMinutes * 10) / 10,
    avgDurationSeconds: Math.round(avgDurationSeconds),
    spanMinutes: Math.round(spanMinutes),
    threshold,
  };
}

/**
 * Runs whenever a new ContractionLog is created.
 * 1. Pull the pattern window of logs and compute avg frequency/duration.
 * 2. Compare against the patient's configured threshold.
 * 3. If crossed and no unacknowledged alert exists, create an Alert.
 * 4. Compute ETA from the midwife's last known location to the patient.
 * 5. Push-notify the assigned midwife and emit realtime updates.
 * Returns the created alert row, or null if no alert was raised.
 */
export async function evaluatePatientAfterContraction(patientId) {
  const { rows: patientRows } = await query(
    'SELECT * FROM patients WHERE id = $1',
    [patientId]
  );
  const patient = patientRows[0];
  if (!patient || !patient.active) return null;

  const pattern = await analyzeContractionPattern(patient);
  if (!pattern.crossed) return null;

  const { rows: existing } = await query(
    'SELECT id FROM alerts WHERE patient_id = $1 AND acknowledged = FALSE LIMIT 1',
    [patientId]
  );
  if (existing.length > 0) return null; // already alerting; don't re-fire

  let eta = null;
  if (patient.midwife_id) {
    const { rows: midwifeRows } = await query(
      'SELECT id, name, lat, lng FROM midwives WHERE id = $1',
      [patient.midwife_id]
    );
    const midwife = midwifeRows[0];
    if (midwife) {
      eta = await estimateDriveTime(
        { lat: midwife.lat, lng: midwife.lng },
        { lat: patient.lat, lng: patient.lng }
      );
    }
  }

  const { rows: alertRows } = await query(
    `INSERT INTO alerts (patient_id, pattern_detected, eta_seconds, eta_source)
     VALUES ($1, $2, $3, $4)
     RETURNING *`,
    [
      patientId,
      JSON.stringify(pattern),
      eta?.seconds ?? null,
      eta?.source ?? 'unavailable',
    ]
  );
  const alert = alertRows[0];
  const enriched = { ...alert, patient_name: patient.name, patient_address: patient.address };

  if (patient.midwife_id) {
    emitToMidwife(patient.midwife_id, 'alert:new', enriched);
    await sendPush('midwife', patient.midwife_id, {
      title: `Labor alert: ${patient.name}`,
      body:
        `Contractions avg ${pattern.avgFrequencyMinutes} min apart, ` +
        `${pattern.avgDurationSeconds}s long, sustained ${pattern.spanMinutes} min. ` +
        `ETA to patient: ${formatEta(eta?.seconds)}.`,
      tag: `alert-${alert.id}`,
      url: `/midwife/patients/${patientId}`,
    });
  }
  emitToPatient(patientId, 'alert:new', enriched);

  return enriched;
}
