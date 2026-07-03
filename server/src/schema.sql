-- Midwife Companion schema. Idempotent: safe to re-run.

CREATE TABLE IF NOT EXISTS midwives (
  id            SERIAL PRIMARY KEY,
  name          TEXT NOT NULL,
  email         TEXT NOT NULL UNIQUE,
  phone         TEXT,
  practice_name TEXT,
  password_hash TEXT NOT NULL,
  lat           DOUBLE PRECISION,
  lng           DOUBLE PRECISION,
  location_updated_at TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS patients (
  id            SERIAL PRIMARY KEY,
  name          TEXT NOT NULL,
  email         TEXT NOT NULL UNIQUE,
  phone         TEXT,
  password_hash TEXT NOT NULL,
  address       TEXT,
  lat           DOUBLE PRECISION,
  lng           DOUBLE PRECISION,
  due_date      DATE,
  midwife_id    INTEGER REFERENCES midwives(id),
  -- Alert threshold settings (defaults = the 5-1-1 rule)
  threshold_frequency_minutes INTEGER NOT NULL DEFAULT 5,   -- contractions <= N minutes apart
  threshold_duration_seconds  INTEGER NOT NULL DEFAULT 60,  -- lasting >= N seconds
  threshold_pattern_minutes   INTEGER NOT NULL DEFAULT 60,  -- sustained for >= N minutes
  -- Intake reminder window (midwife-configured, default 4 hours)
  intake_reminder_minutes     INTEGER NOT NULL DEFAULT 240,
  active        BOOLEAN NOT NULL DEFAULT TRUE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS contraction_logs (
  id          SERIAL PRIMARY KEY,
  patient_id  INTEGER NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
  start_time  TIMESTAMPTZ NOT NULL,
  end_time    TIMESTAMPTZ,
  logged_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_contraction_patient_start
  ON contraction_logs (patient_id, start_time DESC);

CREATE TABLE IF NOT EXISTS intake_logs (
  id          SERIAL PRIMARY KEY,
  patient_id  INTEGER NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
  type        TEXT NOT NULL CHECK (type IN ('water', 'food', 'medication')),
  amount      TEXT,          -- e.g. "8 oz" for water, dose for medication
  description TEXT,          -- free text for food, medication name, etc.
  logged_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_intake_patient_logged
  ON intake_logs (patient_id, logged_at DESC);

CREATE TABLE IF NOT EXISTS medication_reminders (
  id             SERIAL PRIMARY KEY,
  patient_id     INTEGER NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
  name           TEXT NOT NULL,
  dose           TEXT,
  interval_hours DOUBLE PRECISION NOT NULL,
  next_due_at    TIMESTAMPTZ NOT NULL,
  active         BOOLEAN NOT NULL DEFAULT TRUE,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS alerts (
  id               SERIAL PRIMARY KEY,
  patient_id       INTEGER NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
  triggered_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  pattern_detected JSONB NOT NULL,   -- { avgFrequencyMinutes, avgDurationSeconds, spanMinutes, contractionCount, threshold }
  eta_seconds      INTEGER,
  eta_source       TEXT,             -- 'openrouteservice' | 'straight-line-estimate' | 'unavailable'
  acknowledged     BOOLEAN NOT NULL DEFAULT FALSE,
  acknowledged_at  TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_alerts_patient ON alerts (patient_id, triggered_at DESC);

-- Web Push subscriptions for midwives and patients.
CREATE TABLE IF NOT EXISTS push_subscriptions (
  id           SERIAL PRIMARY KEY,
  owner_type   TEXT NOT NULL CHECK (owner_type IN ('midwife', 'patient')),
  owner_id     INTEGER NOT NULL,
  subscription JSONB NOT NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (owner_type, owner_id, subscription)
);

-- Tracks the last time we nudged a patient about water/food so the reminder
-- job doesn't spam every tick once the window is exceeded.
CREATE TABLE IF NOT EXISTS intake_reminder_state (
  patient_id       INTEGER NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
  type             TEXT NOT NULL CHECK (type IN ('water', 'food')),
  last_reminded_at TIMESTAMPTZ NOT NULL,
  PRIMARY KEY (patient_id, type)
);
