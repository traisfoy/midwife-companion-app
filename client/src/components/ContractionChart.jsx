// Contraction pattern over time: two stacked panels sharing one time axis
// (duration and interval are different scales, so they never share an axis).
// Panel 1: duration of each contraction (bars, series-1 blue).
// Panel 2: interval since previous contraction (dots + line, series-2 aqua).
// Dashed reference lines mark the patient's alert thresholds.
import { useMemo, useState } from 'react';
import { fmtTime, fmtDuration } from '../format.js';

const W = 860;
const PANEL_H = 130;
const GAP = 34;
const M = { top: 18, right: 16, bottom: 26, left: 44 };
const H = M.top + PANEL_H * 2 + GAP + M.bottom;

export default function ContractionChart({ contractions, thresholds }) {
  const [hover, setHover] = useState(null);

  const data = useMemo(() => {
    const done = contractions
      .filter((c) => c.end_time)
      .map((c) => ({
        ...c,
        start: new Date(c.start_time).getTime(),
        durationSec: (new Date(c.end_time) - new Date(c.start_time)) / 1000,
      }))
      .sort((a, b) => a.start - b.start);
    return done.map((c, i) => ({
      ...c,
      intervalMin: i > 0 ? (c.start - done[i - 1].start) / 60000 : null,
    }));
  }, [contractions]);

  if (data.length === 0) {
    return <p className="hint">No contractions in the last 24 hours.</p>;
  }

  const t0 = data[0].start;
  const t1 = data[data.length - 1].start;
  const span = Math.max(t1 - t0, 30 * 60 * 1000); // never narrower than 30 min
  const x = (t) => M.left + ((t - t0) / span) * (W - M.left - M.right);

  const maxDur = Math.max(90, thresholds.durationSeconds * 1.5, ...data.map((d) => d.durationSec));
  const intervals = data.filter((d) => d.intervalMin != null);
  const maxInt = Math.max(15, thresholds.frequencyMinutes * 2, ...intervals.map((d) => d.intervalMin));

  const durY = (v) => M.top + PANEL_H - (v / maxDur) * PANEL_H;
  const intTop = M.top + PANEL_H + GAP;
  const intY = (v) => intTop + PANEL_H - (v / maxInt) * PANEL_H;

  // Time axis ticks: 4 evenly spaced.
  const ticks = [0, 1, 2, 3].map((i) => t0 + (span * i) / 3);

  const linePath = intervals
    .map((d, i) => `${i === 0 ? 'M' : 'L'}${x(d.start).toFixed(1)},${intY(d.intervalMin).toFixed(1)}`)
    .join(' ');

  return (
    <div className="chart-wrap" style={{ position: 'relative' }}>
      <div className="legend">
        <span><span className="swatch" style={{ background: 'var(--series-1)' }} />Duration (seconds)</span>
        <span><span className="swatch" style={{ background: 'var(--series-2)' }} />Interval between starts (minutes)</span>
        <span style={{ color: 'var(--text-muted)' }}>┅ alert threshold</span>
      </div>
      <svg viewBox={`0 0 ${W} ${H}`} style={{ width: '100%', minWidth: 560, display: 'block' }}>
        {/* Panel titles */}
        <text x={M.left} y={M.top - 6} fontSize="11" fill="var(--text-muted)">DURATION</text>
        <text x={M.left} y={intTop - 6} fontSize="11" fill="var(--text-muted)">INTERVAL</text>

        {/* Gridlines + y labels for both panels */}
        {[0.5, 1].map((f) => (
          <g key={f}>
            <line x1={M.left} x2={W - M.right} y1={durY(maxDur * f)} y2={durY(maxDur * f)} stroke="var(--grid)" strokeWidth="1" />
            <text x={M.left - 6} y={durY(maxDur * f) + 4} fontSize="10" textAnchor="end" fill="var(--text-muted)">
              {Math.round(maxDur * f)}s
            </text>
            <line x1={M.left} x2={W - M.right} y1={intY(maxInt * f)} y2={intY(maxInt * f)} stroke="var(--grid)" strokeWidth="1" />
            <text x={M.left - 6} y={intY(maxInt * f) + 4} fontSize="10" textAnchor="end" fill="var(--text-muted)">
              {Math.round(maxInt * f)}m
            </text>
          </g>
        ))}

        {/* Threshold reference lines (dashed) */}
        <line x1={M.left} x2={W - M.right} y1={durY(thresholds.durationSeconds)} y2={durY(thresholds.durationSeconds)}
          stroke="var(--text-muted)" strokeWidth="1" strokeDasharray="5 4" />
        <text x={W - M.right} y={durY(thresholds.durationSeconds) - 4} fontSize="10" textAnchor="end" fill="var(--text-muted)"
          stroke="var(--surface)" strokeWidth="3" paintOrder="stroke">
          alert if ≥ {thresholds.durationSeconds}s
        </text>
        <line x1={M.left} x2={W - M.right} y1={intY(thresholds.frequencyMinutes)} y2={intY(thresholds.frequencyMinutes)}
          stroke="var(--text-muted)" strokeWidth="1" strokeDasharray="5 4" />
        <text x={W - M.right} y={intY(thresholds.frequencyMinutes) - 4} fontSize="10" textAnchor="end" fill="var(--text-muted)"
          stroke="var(--surface)" strokeWidth="3" paintOrder="stroke">
          alert if ≤ {thresholds.frequencyMinutes} min
        </text>

        {/* Baselines */}
        <line x1={M.left} x2={W - M.right} y1={M.top + PANEL_H} y2={M.top + PANEL_H} stroke="var(--baseline)" strokeWidth="1" />
        <line x1={M.left} x2={W - M.right} y1={intTop + PANEL_H} y2={intTop + PANEL_H} stroke="var(--baseline)" strokeWidth="1" />

        {/* Duration bars: thin, rounded top, anchored to baseline */}
        {data.map((d) => {
          const y = durY(d.durationSec);
          return (
            <g key={d.id}>
              <rect
                x={x(d.start) - 3}
                y={y}
                width={6}
                height={M.top + PANEL_H - y}
                rx={3}
                fill="var(--series-1)"
              />
              {/* oversized invisible hit target */}
              <rect
                x={x(d.start) - 9}
                y={M.top}
                width={18}
                height={PANEL_H}
                fill="transparent"
                onMouseEnter={() => setHover({ d, px: x(d.start), py: y })}
                onMouseLeave={() => setHover(null)}
              />
            </g>
          );
        })}

        {/* Interval line + dots */}
        {intervals.length > 1 && <path d={linePath} fill="none" stroke="var(--series-2)" strokeWidth="2" />}
        {intervals.map((d) => (
          <g key={d.id}>
            <circle cx={x(d.start)} cy={intY(d.intervalMin)} r={4} fill="var(--series-2)" stroke="var(--surface)" strokeWidth="2" />
            <rect
              x={x(d.start) - 9}
              y={intTop}
              width={18}
              height={PANEL_H}
              fill="transparent"
              onMouseEnter={() => setHover({ d, px: x(d.start), py: intY(d.intervalMin) })}
              onMouseLeave={() => setHover(null)}
            />
          </g>
        ))}

        {/* Time axis */}
        {ticks.map((t, i) => (
          <text
            key={i}
            x={x(t)}
            y={H - 8}
            fontSize="10"
            fill="var(--text-muted)"
            textAnchor={i === 0 ? 'start' : i === ticks.length - 1 ? 'end' : 'middle'}
          >
            {fmtTime(t)}
          </text>
        ))}
      </svg>

      {hover && (
        <div
          className="chart-tooltip"
          style={{
            left: `${(hover.px / W) * 100}%`,
            top: `${(hover.py / H) * 100}%`,
            transform: 'translate(-50%, -120%)',
          }}
        >
          <strong>{fmtTime(hover.d.start_time)}</strong>
          <br />
          duration {fmtDuration(hover.d.durationSec)}
          {hover.d.intervalMin != null && (
            <>
              <br />
              {Math.round(hover.d.intervalMin * 10) / 10} min since previous
            </>
          )}
        </div>
      )}
    </div>
  );
}
