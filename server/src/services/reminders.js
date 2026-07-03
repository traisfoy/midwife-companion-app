// Background reminder jobs (simple setInterval scheduler, fine for a prototype):
//  - Water/food nudges when a patient hasn't logged intake within their
//    midwife-configured window (default 4 hours). Re-nudges at most once per window.
//  - Recurring medication reminders when next_due_at passes.
import { query } from '../db.js';
import { sendPush } from './push.js';
import { emitToPatient } from './realtime.js';

const TICK_MS = 60 * 1000;

async function checkIntakeReminders() {
  for (const type of ['water', 'food']) {
    const { rows } = await query(
      `SELECT p.id, p.name, p.intake_reminder_minutes
       FROM patients p
       WHERE p.active
         AND NOT EXISTS (
           SELECT 1 FROM intake_logs il
           WHERE il.patient_id = p.id AND il.type = $1
             AND il.logged_at >= now() - make_interval(mins => p.intake_reminder_minutes)
         )
         AND NOT EXISTS (
           SELECT 1 FROM intake_reminder_state s
           WHERE s.patient_id = p.id AND s.type = $1
             AND s.last_reminded_at >= now() - make_interval(mins => p.intake_reminder_minutes)
         )`,
      [type]
    );
    for (const patient of rows) {
      const hours = Math.round((patient.intake_reminder_minutes / 60) * 10) / 10;
      const message = {
        title: type === 'water' ? 'Time to hydrate 💧' : 'Time to eat 🍎',
        body: `You haven't logged any ${type} in the last ${hours} hours. A quick log keeps your midwife in the loop.`,
        tag: `intake-${type}-${patient.id}`,
        url: '/patient',
      };
      await sendPush('patient', patient.id, message);
      emitToPatient(patient.id, 'reminder', { type, ...message });
      await query(
        `INSERT INTO intake_reminder_state (patient_id, type, last_reminded_at)
         VALUES ($1, $2, now())
         ON CONFLICT (patient_id, type) DO UPDATE SET last_reminded_at = now()`,
        [patient.id, type]
      );
    }
  }
}

async function checkMedicationReminders() {
  const { rows } = await query(
    `UPDATE medication_reminders r
     SET next_due_at = next_due_at + make_interval(hours => interval_hours)
     FROM patients p
     WHERE r.patient_id = p.id AND p.active AND r.active AND r.next_due_at <= now()
     RETURNING r.id, r.patient_id, r.name, r.dose`
  );
  for (const med of rows) {
    const message = {
      title: `Medication reminder: ${med.name}`,
      body: `Time to take ${med.name}${med.dose ? ` (${med.dose})` : ''}. Log it once you have.`,
      tag: `med-${med.id}`,
      url: '/patient',
    };
    await sendPush('patient', med.patient_id, message);
    emitToPatient(med.patient_id, 'reminder', { type: 'medication', ...message });
  }
}

export function startReminderJobs() {
  setInterval(() => {
    checkIntakeReminders().catch((err) =>
      console.error('Intake reminder job failed:', err.message)
    );
    checkMedicationReminders().catch((err) =>
      console.error('Medication reminder job failed:', err.message)
    );
  }, TICK_MS);
  console.log('Reminder jobs started (60s tick).');
}
