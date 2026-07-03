import { useCallback, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { api } from '../../api.js';
import { enablePushNotifications } from '../../push.js';
import { getSocket } from '../../socket.js';
import { fmtEta, fmtDateTime, timeAgo } from '../../format.js';

export default function Dashboard() {
  const [caseload, setCaseload] = useState([]);
  const [alerts, setAlerts] = useState([]);
  const [toast, setToast] = useState('');
  const [pushState, setPushState] = useState('idle');

  const showToast = useCallback((msg) => {
    setToast(msg);
    setTimeout(() => setToast(''), 5000);
  }, []);

  const reload = useCallback(async () => {
    const [cRes, aRes] = await Promise.all([
      api('/midwife/caseload'),
      api('/midwife/alerts'),
    ]);
    setCaseload(cRes.caseload);
    setAlerts(aRes.alerts);
  }, []);

  useEffect(() => {
    reload().catch((err) => showToast(err.message));
    const socket = getSocket();
    const onUpdate = () => reload().catch(() => {});
    const onAlert = (alert) => {
      showToast(`🚨 Labor alert: ${alert.patient_name} — ETA ${fmtEta(alert.eta_seconds)}`);
      reload().catch(() => {});
    };
    socket.on('alert:new', onAlert);
    socket.on('alert:acknowledged', onUpdate);
    socket.on('contraction:new', onUpdate);
    socket.on('intake:new', onUpdate);
    // Polling backstop in case the socket drops.
    const poll = setInterval(onUpdate, 30000);
    return () => {
      socket.off('alert:new', onAlert);
      socket.off('alert:acknowledged', onUpdate);
      socket.off('contraction:new', onUpdate);
      socket.off('intake:new', onUpdate);
      clearInterval(poll);
    };
  }, [reload, showToast]);

  async function acknowledge(id) {
    try {
      await api(`/midwife/alerts/${id}/acknowledge`, { method: 'POST' });
      await reload();
    } catch (err) {
      showToast(err.message);
    }
  }

  async function enablePush() {
    setPushState('working');
    const res = await enablePushNotifications().catch(() => ({ ok: false }));
    setPushState(res.ok ? 'on' : 'failed');
  }

  const open = alerts.filter((a) => !a.acknowledged);

  return (
    <div>
      <div className="btn-row" style={{ marginBottom: 16 }}>
        {pushState !== 'on' && (
          <button className="btn" onClick={enablePush} disabled={pushState === 'working'}>
            {pushState === 'failed' ? 'Push unavailable in this browser' : '🔔 Enable push alerts'}
          </button>
        )}
        <LocationControl onSaved={() => showToast('Location updated — ETAs will use it.')} onError={showToast} />
      </div>

      <div className="card">
        <h2>Alerts {open.length > 0 && <span className="badge badge-critical">{open.length} active</span>}</h2>
        {alerts.length === 0 && <p className="hint">No alerts yet.</p>}
        {alerts.map((a) => (
          <div key={a.id} className={`alert-item ${a.acknowledged ? 'acked' : ''}`}>
            <div style={{ display: 'flex', justifyContent: 'space-between', gap: 12, flexWrap: 'wrap' }}>
              <div>
                <strong>{a.patient_name}</strong>
                <div className="hint">
                  {fmtDateTime(a.triggered_at)} · avg {a.pattern_detected.avgFrequencyMinutes} min apart,{' '}
                  {a.pattern_detected.avgDurationSeconds}s long, sustained {a.pattern_detected.spanMinutes} min
                </div>
                <div className="hint">{a.patient_address}</div>
              </div>
              <div style={{ textAlign: 'right' }}>
                <div className="eta">🚗 {fmtEta(a.eta_seconds)}</div>
                <div className="hint">{a.eta_source === 'openrouteservice' ? 'driving route' : 'straight-line estimate'}</div>
                {!a.acknowledged ? (
                  <button className="btn btn-primary" style={{ marginTop: 6 }} onClick={() => acknowledge(a.id)}>
                    Acknowledge
                  </button>
                ) : (
                  <span className="hint">acknowledged {timeAgo(a.acknowledged_at)}</span>
                )}
              </div>
            </div>
          </div>
        ))}
      </div>

      <div className="card">
        <h2>Caseload</h2>
        {caseload.map((p) => (
          <Link key={p.id} to={`/midwife/patients/${p.id}`} className={`patient-row ${p.active_alert ? 'alerting' : ''}`}>
            <div>
              <strong>{p.name}</strong>{' '}
              {p.active_alert ? (
                <span className="badge badge-critical">⚠ IN LABOR PATTERN</span>
              ) : p.pattern?.contractionCount >= 3 ? (
                <span className="badge badge-muted">contracting</span>
              ) : null}
              <div className="meta">
                Due {new Date(p.due_date).toLocaleDateString()} · last contraction{' '}
                {timeAgo(p.last_contraction_at)} · water {timeAgo(p.last_water_at)} · food{' '}
                {timeAgo(p.last_food_at)}
              </div>
            </div>
            <div className="meta" style={{ textAlign: 'right' }}>
              {p.pattern?.avgFrequencyMinutes != null && (
                <>
                  {p.pattern.avgFrequencyMinutes} min apart / {p.pattern.avgDurationSeconds}s
                  <br />
                </>
              )}
              {p.active_alert && <>ETA {fmtEta(p.active_alert.eta_seconds)}</>}
            </div>
          </Link>
        ))}
      </div>
      {toast && <div className="toast">{toast}</div>}
    </div>
  );
}

function LocationControl({ onSaved, onError }) {
  const [busy, setBusy] = useState(false);

  function useBrowserLocation() {
    if (!navigator.geolocation) return onError('Geolocation unsupported');
    setBusy(true);
    navigator.geolocation.getCurrentPosition(
      async (pos) => {
        try {
          await api('/midwife/location', {
            method: 'PATCH',
            body: { lat: pos.coords.latitude, lng: pos.coords.longitude },
          });
          onSaved();
        } catch (err) {
          onError(err.message);
        } finally {
          setBusy(false);
        }
      },
      (err) => {
        setBusy(false);
        onError(`Location error: ${err.message}. You can set it manually.`);
      }
    );
  }

  async function setManually() {
    const input = prompt('Enter your current location as "lat, lng":');
    if (!input) return;
    const [lat, lng] = input.split(',').map((s) => parseFloat(s.trim()));
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) return onError('Could not parse lat/lng');
    try {
      await api('/midwife/location', { method: 'PATCH', body: { lat, lng } });
      onSaved();
    } catch (err) {
      onError(err.message);
    }
  }

  return (
    <>
      <button className="btn" onClick={useBrowserLocation} disabled={busy}>
        📍 Update my location
      </button>
      <button className="btn-ghost" onClick={setManually}>
        set manually
      </button>
    </>
  );
}
