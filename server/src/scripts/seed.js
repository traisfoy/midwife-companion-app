// Seeds one midwife and three patients (Portland, OR area) plus a bit of
// recent intake history so the dashboard isn't empty. Idempotent-ish: wipes
// and re-creates app data every run.
import bcrypt from 'bcryptjs';
import { pool } from '../db.js';

async function main() {
  const hash = (pw) => bcrypt.hashSync(pw, 10);

  await pool.query(
    `TRUNCATE intake_reminder_state, push_subscriptions, alerts,
       medication_reminders, intake_logs, contraction_logs, patients, midwives
     RESTART IDENTITY CASCADE`
  );

  const midwife = (
    await pool.query(
      `INSERT INTO midwives (name, email, phone, practice_name, password_hash, lat, lng, location_updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, now())
       RETURNING id`,
      [
        'Sarah Bennett',
        'sarah@peacefulbeginnings.test',
        '503-555-0100',
        'Peaceful Beginnings Midwifery',
        hash('midwife123'),
        45.5231, // near downtown Portland, OR
        -122.6765,
      ]
    )
  ).rows[0];

  const patients = [
    {
      name: 'Maria Gonzalez',
      email: 'maria@example.test',
      phone: '503-555-0101',
      address: '4035 SE Hawthorne Blvd, Portland, OR 97214',
      lat: 45.5121,
      lng: -122.6208,
      dueInDays: 2,
    },
    {
      name: 'Jasmine Carter',
      email: 'jasmine@example.test',
      phone: '503-555-0102',
      address: '7000 NE Airport Way, Portland, OR 97218',
      lat: 45.5887,
      lng: -122.5975,
      dueInDays: 14,
    },
    {
      name: 'Emily Chen',
      email: 'emily@example.test',
      phone: '503-555-0103',
      address: '12000 SW 49th Ave, Portland, OR 97219',
      lat: 45.4442,
      lng: -122.7247,
      dueInDays: 35,
    },
  ];

  const patientIds = [];
  for (const p of patients) {
    const res = await pool.query(
      `INSERT INTO patients (name, email, phone, password_hash, address, lat, lng, due_date, midwife_id)
       VALUES ($1, $2, $3, $4, $5, $6, $7, now()::date + $8::int, $9)
       RETURNING id`,
      [p.name, p.email, p.phone, hash('patient123'), p.address, p.lat, p.lng, p.dueInDays, midwife.id]
    );
    patientIds.push(res.rows[0].id);
  }

  // Recent intake history for the first patient so the detail view has data.
  const [mariaId] = patientIds;
  const intake = [
    ['water', '8 oz', null, '6 hours'],
    ['water', '16 oz', null, '3 hours'],
    ['food', null, 'Toast with peanut butter and a banana', '5 hours'],
    ['food', null, 'Chicken soup', '2 hours'],
    ['medication', '400 mg', 'Ibuprofen', '4 hours'],
  ];
  for (const [type, amount, description, ago] of intake) {
    await pool.query(
      `INSERT INTO intake_logs (patient_id, type, amount, description, logged_at)
       VALUES ($1, $2, $3, $4, now() - $5::interval)`,
      [mariaId, type, amount, description, ago]
    );
  }

  // A mild early-labor contraction pattern (does NOT cross 5-1-1) for Maria.
  for (let i = 6; i >= 1; i--) {
    const minutesAgo = i * 12; // ~12 min apart
    await pool.query(
      `INSERT INTO contraction_logs (patient_id, start_time, end_time, logged_at)
       VALUES ($1, now() - make_interval(mins => $2), now() - make_interval(mins => $2) + interval '45 seconds', now() - make_interval(mins => $2))`,
      [mariaId, minutesAgo]
    );
  }

  // A prenatal vitamin reminder for Maria.
  await pool.query(
    `INSERT INTO medication_reminders (patient_id, name, dose, interval_hours, next_due_at)
     VALUES ($1, 'Prenatal vitamin', '1 tablet', 24, now() + interval '24 hours')`,
    [mariaId]
  );

  console.log('Seed complete.');
  console.log('  Midwife login:  sarah@peacefulbeginnings.test / midwife123');
  console.log('  Patient logins: maria@example.test, jasmine@example.test, emily@example.test / patient123');
  await pool.end();
}

main().catch((err) => {
  console.error('Seed failed:', err);
  process.exit(1);
});
