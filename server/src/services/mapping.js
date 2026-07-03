// Mapping service: driving ETA + address geocoding via OpenRouteService
// (free tier) when ORS_API_KEY is set, with a straight-line fallback so the
// prototype works fully offline / keyless.
import { config } from '../config.js';

const ORS_BASE = 'https://api.openrouteservice.org';

// Haversine distance in kilometers.
function haversineKm(a, b) {
  const R = 6371;
  const toRad = (d) => (d * Math.PI) / 180;
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(a.lat)) * Math.cos(toRad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}

/**
 * Estimate drive time between two {lat, lng} points.
 * Returns { seconds, distanceKm, source } or null if either point is missing.
 */
export async function estimateDriveTime(from, to) {
  if (!from?.lat || !from?.lng || !to?.lat || !to?.lng) return null;

  if (config.orsApiKey) {
    try {
      const res = await fetch(`${ORS_BASE}/v2/directions/driving-car`, {
        method: 'POST',
        headers: {
          Authorization: config.orsApiKey,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          coordinates: [
            [from.lng, from.lat],
            [to.lng, to.lat],
          ],
        }),
      });
      if (res.ok) {
        const data = await res.json();
        const summary = data?.routes?.[0]?.summary;
        if (summary) {
          return {
            seconds: Math.round(summary.duration),
            distanceKm: summary.distance / 1000,
            source: 'openrouteservice',
          };
        }
      } else {
        console.warn('ORS directions failed:', res.status, await res.text());
      }
    } catch (err) {
      console.warn('ORS directions error, falling back:', err.message);
    }
  }

  // Fallback: straight-line distance * 1.4 road-winding factor at 45 km/h
  // average urban driving speed. Rough, but good enough to triage urgency.
  const km = haversineKm(from, to) * 1.4;
  return {
    seconds: Math.round((km / 45) * 3600),
    distanceKm: km,
    source: 'straight-line-estimate',
  };
}

/**
 * Geocode a free-text address to { lat, lng } via ORS. Returns null when no
 * API key is configured or nothing matches — callers keep any existing coords.
 */
export async function geocodeAddress(address) {
  if (!config.orsApiKey || !address) return null;
  try {
    const url = new URL(`${ORS_BASE}/geocode/search`);
    url.searchParams.set('api_key', config.orsApiKey);
    url.searchParams.set('text', address);
    url.searchParams.set('size', '1');
    const res = await fetch(url);
    if (!res.ok) return null;
    const data = await res.json();
    const coords = data?.features?.[0]?.geometry?.coordinates;
    if (!coords) return null;
    return { lat: coords[1], lng: coords[0] };
  } catch (err) {
    console.warn('Geocoding failed:', err.message);
    return null;
  }
}

export function formatEta(seconds) {
  if (seconds == null) return 'unknown';
  const mins = Math.round(seconds / 60);
  if (mins < 60) return `${mins} min`;
  return `${Math.floor(mins / 60)} hr ${mins % 60} min`;
}
