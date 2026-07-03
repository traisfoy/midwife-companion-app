import { useCallback, useEffect, useRef, useState } from 'react';
import { api } from '../../api.js';
import { enablePushNotifications } from '../../push.js';
import { getSocket } from '../../socket.js';
import { fmtDuration, fmtTime, fmtDateTime, timeAgo } from '../../format.js';

export default function PatientHome() {
  const [me, setMe] = useState(null);
  const [contractions, setContractions] = useState([]);
  const [intake, setIntake] = useState([]);
  const [reminders, setReminders] = useState([]);
  const [toast, setToast] = useState('');
  const [pushState, setPushState] = useState('idle');

  const showToast = useCallback((msg) => {
    setToast(msg);
    setTimeout(() => setToast(''), 4000);
  }, []);

  const reload = useCallback(async () => {
    const [meRes, cRes, iRes, rRes] = await Promise.all([
      api('/patient/me'),
      api('/patient/contractions?hours=24'),
      api('/patient/intake?hours=48'),
      api('/patient/medication-reminders'),
    ]);
    setMe(meRes.patient);
    setContractions(cRes.contractions);
    setIntake(iRes.intake);
    setReminders(rRes.reminders);
  }, []);

  useEffect(() => {
    reload().catch((err) => showToast(err.message));
    const socket = getSocket();
    const onReminder = (r) => showToast(`${r.title} — ${r.body}`);
    const onAlert = () =>
      showToast('Your contraction pattern crossed your alert threshold. Your midwife has been notified.');
    socket.on('reminder', onReminder);
    socket.on('alert:new', onAlert);
    return () => {
      socket.off('reminder', onReminder);
      socket.off('alert:new', onAlert);
    };
  }, [reload, showToast]);

  async function enablePush() {
    setPushState('working');
    const res = await enablePushNotifications().catch(() => ({ ok: false, reason: 'error' }));
    setPushState(res.ok ? 'on' : 'failed');
  }

  return (
    <div>
      {me && (
        <p className="hint">
          Due {new Date(me.due_date).toLocaleDateString()} · Midwife: {me.midwife_name} (
          {me.practice_name})
        </p>
      )}
      {pushState !== 'on' && (
        <button className="btn" onClick={enablePush} disabled={pushState === 'working'}>
          {pushState === 'failed' ? 'Notifications unavailable in this browser' : '🔔 Enable reminders & notifications'}
        </button>
      )}

      <ContractionTimer
        contractions={contractions}
        onLogged={(log, alert) => {
          setContractions((prev) => [log, ...prev]);
          if (alert) {
            showToast('Pattern threshold crossed — your midwife has been alerted.');
          }
        }}
        onError={showToast}
      />
      <WaterLogger onLogged={(l) => setIntake((p) => [l, ...p])} onError={showToast} />
      <FoodLogger onLogged={(l) => setIntake((p) => [l, ...p])} onError={showToast} />
      <MedicationLogger
        reminders={reminders}
        onLogged={(l) => setIntake((p) => [l, ...p])}
        onRemindersChanged={setReminders}
        onError={showToast}
      />
      <IntakeHistory intake={intake} />
      {toast && <div className="toast">{toast}</div>}
    </div>
  );
}

function ContractionTimer({ contractions, onLogged, onError }) {
  const [startedAt, setStartedAt] = useState(null);
  const [elapsed, setElapsed] = useState(0);
  const tick = useRef(null);

  useEffect(() => () => clearInterval(tick.current), []);

  function start() {
    const now = Date.now();
    setStartedAt(now);
    setElapsed(0);
    tick.current = setInterval(() => setElapsed(Math.round((Date.now() - now) / 1000)), 250);
  }

  async function stop() {
    clearInterval(tick.current);
    const start_ = startedAt;
    setStartedAt(null);
    try {
      const { contraction, alert } = await api('/patient/contractions', {
        method: 'POST',
        body: {
          startTime: new Date(start_).toISOString(),
          endTime: new Date().toISOString(),
        },
      });
      onLogged(contraction, alert);
    } catch (err) {
      onError(err.message);
    }
  }

  // Today's list, newest first, with frequency = gap to the previous start.
  const today = new Date().toDateString();
  const todays = contractions.filter((c) => new Date(c.start_time).toDateString() === today);
  const rows = todays.map((c, i) => {
    const next = todays[i + 1]; // list is newest-first, so [i+1] is the previous contraction
    const freqMin = next
      ? (new Date(c.start_time) - new Date(next.start_time)) / 60000
      : null;
    const durSec = c.end_time ? (new Date(c.end_time) - new Date(c.start_time)) / 1000 : null;
    return { ...c, freqMin, durSec };
  });

  return (
    <div className="card">
      <h2>Contraction timer</h2>
      {startedAt && <div className="timer-elapsed">{fmtDuration(elapsed)}</div>}
      <button className={`timer-btn ${startedAt ? 'active' : ''}`} onClick={startedAt ? stop : start}>
        {startedAt ? 'Stop — contraction ended' : 'Start contraction'}
      </button>
      <h3>Today ({rows.length})</h3>
      {rows.length === 0 ? (
        <p className="hint">No contractions logged today.</p>
      ) : (
        <table className="data">
          <thead>
            <tr>
              <th>Start</th>
              <th>Duration</th>
              <th>Apart</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((r) => (
              <tr key={r.id}>
                <td>{fmtTime(r.start_time)}</td>
                <td>{fmtDuration(r.durSec)}</td>
                <td>{r.freqMin != null ? `${Math.round(r.freqMin)} min` : '—'}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}

function WaterLogger({ onLogged, onError }) {
  const [custom, setCustom] = useState('');

  async function log(amount) {
    try {
      const { intake } = await api('/patient/intake', {
        method: 'POST',
        body: { type: 'water', amount },
      });
      onLogged(intake);
    } catch (err) {
      onError(err.message);
    }
  }

  return (
    <div className="card">
      <h2>Water</h2>
      <div className="btn-row">
        <button className="btn btn-primary" onClick={() => log('8 oz')}>+ 8 oz</button>
        <button className="btn btn-primary" onClick={() => log('16 oz')}>+ 16 oz</button>
        <input
          type="number"
          min="1"
          placeholder="Custom (oz)"
          value={custom}
          onChange={(e) => setCustom(e.target.value)}
          style={{ width: 120 }}
        />
        <button
          className="btn"
          onClick={() => {
            if (custom > 0) {
              log(`${custom} oz`);
              setCustom('');
            }
          }}
        >
          Add
        </button>
      </div>
    </div>
  );
}

function FoodLogger({ onLogged, onError }) {
  const [text, setText] = useState('');

  async function submit(e) {
    e.preventDefault();
    if (!text.trim()) return;
    try {
      const { intake } = await api('/patient/intake', {
        method: 'POST',
        body: { type: 'food', description: text.trim() },
      });
      onLogged(intake);
      setText('');
    } catch (err) {
      onError(err.message);
    }
  }

  return (
    <div className="card">
      <h2>Food</h2>
      <form onSubmit={submit} className="btn-row">
        <input
          placeholder="What did you eat?"
          value={text}
          onChange={(e) => setText(e.target.value)}
          style={{ flex: 1, minWidth: 200 }}
        />
        <button className="btn btn-primary">Log</button>
      </form>
    </div>
  );
}

function MedicationLogger({ reminders, onLogged, onRemindersChanged, onError }) {
  const [name, setName] = useState('');
  const [dose, setDose] = useState('');
  const [remind, setRemind] = useState(false);
  const [intervalHours, setIntervalHours] = useState('8');

  async function submit(e) {
    e.preventDefault();
    if (!name.trim()) return;
    try {
      const { intake } = await api('/patient/intake', {
        method: 'POST',
        body: { type: 'medication', description: name.trim(), amount: dose || null },
      });
      onLogged(intake);
      if (remind) {
        const { reminder } = await api('/patient/medication-reminders', {
          method: 'POST',
          body: { name: name.trim(), dose: dose || null, intervalHours: parseFloat(intervalHours) },
        });
        onRemindersChanged((prev) => [...prev, reminder]);
      }
      setName('');
      setDose('');
      setRemind(false);
    } catch (err) {
      onError(err.message);
    }
  }

  async function removeReminder(id) {
    try {
      await api(`/patient/medication-reminders/${id}`, { method: 'DELETE' });
      onRemindersChanged((prev) => prev.filter((r) => r.id !== id));
    } catch (err) {
      onError(err.message);
    }
  }

  return (
    <div className="card">
      <h2>Medication</h2>
      <form onSubmit={submit}>
        <div className="btn-row" style={{ marginBottom: 8 }}>
          <input
            placeholder="Name (e.g. Prenatal vitamin)"
            value={name}
            onChange={(e) => setName(e.target.value)}
            style={{ flex: 1, minWidth: 180 }}
          />
          <input
            placeholder="Dose"
            value={dose}
            onChange={(e) => setDose(e.target.value)}
            style={{ width: 110 }}
          />
          <button className="btn btn-primary">Log dose</button>
        </div>
        <label className="hint" style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
          <input
            type="checkbox"
            checked={remind}
            onChange={(e) => setRemind(e.target.checked)}
            style={{ width: 'auto' }}
          />
          Remind me every
          <input
            type="number"
            min="0.5"
            step="0.5"
            value={intervalHours}
            onChange={(e) => setIntervalHours(e.target.value)}
            style={{ width: 70, padding: '3px 6px' }}
            disabled={!remind}
          />
          hours
        </label>
      </form>
      {reminders.length > 0 && (
        <>
          <h3>Active reminders</h3>
          <table className="data">
            <tbody>
              {reminders.map((r) => (
                <tr key={r.id}>
                  <td>
                    {r.name} {r.dose ? `(${r.dose})` : ''} — every {r.interval_hours}h, next{' '}
                    {timeAgo(r.next_due_at).includes('ago')
                      ? 'due now'
                      : fmtDateTime(r.next_due_at)}
                  </td>
                  <td style={{ textAlign: 'right' }}>
                    <button className="btn-ghost" onClick={() => removeReminder(r.id)}>
                      ✕
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </>
      )}
    </div>
  );
}

const TYPE_ICON = { water: '💧', food: '🍎', medication: '💊' };

function IntakeHistory({ intake }) {
  return (
    <div className="card">
      <h2>Recent intake (48h)</h2>
      {intake.length === 0 ? (
        <p className="hint">Nothing logged yet.</p>
      ) : (
        <table className="data">
          <tbody>
            {intake.map((l) => (
              <tr key={l.id}>
                <td style={{ width: 30 }}>{TYPE_ICON[l.type]}</td>
                <td>
                  {[l.description, l.amount].filter(Boolean).join(' — ') || l.type}
                </td>
                <td style={{ textAlign: 'right', color: 'var(--text-muted)' }}>
                  {fmtDateTime(l.logged_at)}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}
