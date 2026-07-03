import { useCallback, useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { api } from '../../api.js';
import { getSocket } from '../../socket.js';
import ContractionChart from '../../components/ContractionChart.jsx';
import { fmtDateTime, fmtEta, timeAgo } from '../../format.js';

const TYPE_ICON = { water: '💧', food: '🍎', medication: '💊' };

export default function PatientDetail() {
  const { id } = useParams();
  const [data, setData] = useState(null);
  const [error, setError] = useState('');

  const reload = useCallback(async () => {
    try {
      setData(await api(`/midwife/patients/${id}`));
    } catch (err) {
      setError(err.message);
    }
  }, [id]);

  useEffect(() => {
    reload();
    const socket = getSocket();
    const onUpdate = (payload) => {
      if (String(payload?.patient_id) === String(id)) reload();
    };
    socket.on('contraction:new', onUpdate);
    socket.on('intake:new', onUpdate);
    socket.on('alert:new', onUpdate);
    const poll = setInterval(reload, 30000);
    return () => {
      socket.off('contraction:new', onUpdate);
      socket.off('intake:new', onUpdate);
      socket.off('alert:new', onUpdate);
      clearInterval(poll);
    };
  }, [id, reload]);

  if (error) return <p className="error">{error}</p>;
  if (!data) return <p className="hint">Loading…</p>;

  const { patient, contractions, intake, medicationReminders, alerts, pattern } = data;
  const openAlert = alerts.find((a) => !a.acknowledged);

  return (
    <div>
      <p>
        <Link to="/midwife" style={{ color: 'var(--accent)' }}>← Caseload</Link>
      </p>
      <div className="card">
        <h2>
          {patient.name}{' '}
          {openAlert && <span className="badge badge-critical">⚠ ACTIVE ALERT — ETA {fmtEta(openAlert.eta_seconds)}</span>}
        </h2>
        <p className="hint">
          Due {new Date(patient.due_date).toLocaleDateString()} · {patient.phone} ·{' '}
          {patient.address}
        </p>
        {pattern.avgFrequencyMinutes != null ? (
          <p>
            Last {pattern.threshold.patternMinutes} min: <strong>{pattern.contractionCount}</strong>{' '}
            contractions, avg <strong>{pattern.avgFrequencyMinutes} min</strong> apart, avg{' '}
            <strong>{pattern.avgDurationSeconds}s</strong> long{' '}
            {pattern.crossed ? (
              <span className="badge badge-critical">threshold crossed</span>
            ) : (
              <span className="badge badge-good">below threshold</span>
            )}
          </p>
        ) : (
          <p className="hint">
            Not enough recent contractions to evaluate a pattern ({pattern.contractionCount} in
            the last {pattern.threshold.patternMinutes} min).
          </p>
        )}
      </div>

      <div className="card">
        <h2>Contraction pattern (24h)</h2>
        <ContractionChart
          contractions={contractions}
          thresholds={{
            frequencyMinutes: patient.threshold_frequency_minutes,
            durationSeconds: patient.threshold_duration_seconds,
          }}
        />
      </div>

      <ThresholdConfig patient={patient} onSaved={reload} />

      <div className="card">
        <h2>Medication adherence</h2>
        {medicationReminders.length === 0 ? (
          <p className="hint">No active medication reminders.</p>
        ) : (
          <table className="data">
            <thead>
              <tr><th>Medication</th><th>Schedule</th><th>Last logged</th></tr>
            </thead>
            <tbody>
              {medicationReminders.map((r) => {
                const overdue =
                  !r.last_logged_at ||
                  Date.now() - new Date(r.last_logged_at) > r.interval_hours * 3600 * 1000 * 1.5;
                return (
                  <tr key={r.id}>
                    <td>{r.name} {r.dose ? `(${r.dose})` : ''}</td>
                    <td>every {r.interval_hours}h</td>
                    <td style={{ color: overdue ? 'var(--status-critical)' : 'var(--status-good)' }}>
                      {overdue ? '⚠ ' : '✓ '}{timeAgo(r.last_logged_at)}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
      </div>

      <div className="card">
        <h2>Intake history (72h)</h2>
        {intake.length === 0 ? (
          <p className="hint">Nothing logged.</p>
        ) : (
          <table className="data">
            <tbody>
              {intake.map((l) => (
                <tr key={l.id}>
                  <td style={{ width: 30 }}>{TYPE_ICON[l.type]}</td>
                  <td>{[l.description, l.amount].filter(Boolean).join(' — ') || l.type}</td>
                  <td style={{ textAlign: 'right', color: 'var(--text-muted)' }}>{fmtDateTime(l.logged_at)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      <div className="card">
        <h2>Alert history</h2>
        {alerts.length === 0 ? (
          <p className="hint">No alerts for this patient.</p>
        ) : (
          <table className="data">
            <thead>
              <tr><th>Triggered</th><th>Pattern</th><th>ETA</th><th>Status</th></tr>
            </thead>
            <tbody>
              {alerts.map((a) => (
                <tr key={a.id}>
                  <td>{fmtDateTime(a.triggered_at)}</td>
                  <td>
                    {a.pattern_detected.avgFrequencyMinutes} min / {a.pattern_detected.avgDurationSeconds}s /{' '}
                    {a.pattern_detected.spanMinutes} min
                  </td>
                  <td>{fmtEta(a.eta_seconds)}</td>
                  <td>{a.acknowledged ? `✓ acked ${timeAgo(a.acknowledged_at)}` : '⚠ open'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}

function ThresholdConfig({ patient, onSaved }) {
  const [form, setForm] = useState({
    frequencyMinutes: patient.threshold_frequency_minutes,
    durationSeconds: patient.threshold_duration_seconds,
    patternMinutes: patient.threshold_pattern_minutes,
    intakeReminderMinutes: patient.intake_reminder_minutes,
  });
  const [status, setStatus] = useState('');

  async function save(e) {
    e.preventDefault();
    setStatus('saving');
    try {
      await api(`/midwife/patients/${patient.id}/thresholds`, {
        method: 'PATCH',
        body: form,
      });
      setStatus('saved');
      onSaved();
      setTimeout(() => setStatus(''), 2500);
    } catch (err) {
      setStatus(err.message);
    }
  }

  const set = (k) => (e) => setForm((f) => ({ ...f, [k]: e.target.value }));

  return (
    <div className="card">
      <h2>Alert threshold</h2>
      <p className="hint">
        Alert fires when contractions average ≤ frequency apart AND ≥ duration long, sustained
        over the pattern window. Default is the 5-1-1 rule.
      </p>
      <form onSubmit={save}>
        <div className="form-grid">
          <label>
            Frequency (min apart)
            <input type="number" min="1" value={form.frequencyMinutes} onChange={set('frequencyMinutes')} />
          </label>
          <label>
            Duration (seconds)
            <input type="number" min="10" value={form.durationSeconds} onChange={set('durationSeconds')} />
          </label>
          <label>
            Pattern window (min)
            <input type="number" min="10" value={form.patternMinutes} onChange={set('patternMinutes')} />
          </label>
          <label>
            Intake reminder (min)
            <input type="number" min="30" value={form.intakeReminderMinutes} onChange={set('intakeReminderMinutes')} />
          </label>
        </div>
        <div className="btn-row" style={{ marginTop: 10, alignItems: 'center' }}>
          <button className="btn btn-primary" disabled={status === 'saving'}>Save thresholds</button>
          {status && status !== 'saving' && (
            <span className={status === 'saved' ? 'hint' : 'error'}>
              {status === 'saved' ? '✓ Saved' : status}
            </span>
          )}
        </div>
      </form>
    </div>
  );
}
