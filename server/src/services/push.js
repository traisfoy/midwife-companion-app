// Web Push notifications. VAPID keys come from env, or are generated once and
// persisted to server/.vapid.json (gitignored) so subscriptions survive restarts.
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import webpush from 'web-push';
import { config } from '../config.js';
import { query } from '../db.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const KEY_FILE = path.join(__dirname, '..', '..', '.vapid.json');

let keys = { publicKey: config.vapid.publicKey, privateKey: config.vapid.privateKey };
if (!keys.publicKey || !keys.privateKey) {
  if (existsSync(KEY_FILE)) {
    keys = JSON.parse(readFileSync(KEY_FILE, 'utf8'));
  } else {
    keys = webpush.generateVAPIDKeys();
    writeFileSync(KEY_FILE, JSON.stringify(keys, null, 2));
    console.log('Generated VAPID keypair -> server/.vapid.json');
  }
}
webpush.setVapidDetails(config.vapid.subject, keys.publicKey, keys.privateKey);

export const vapidPublicKey = keys.publicKey;

export async function saveSubscription(ownerType, ownerId, subscription) {
  await query(
    `INSERT INTO push_subscriptions (owner_type, owner_id, subscription)
     VALUES ($1, $2, $3)
     ON CONFLICT (owner_type, owner_id, subscription) DO NOTHING`,
    [ownerType, ownerId, JSON.stringify(subscription)]
  );
}

/**
 * Send a push notification to every registered subscription for a user.
 * Dead subscriptions (410/404) are pruned. Failures never throw — push is
 * best-effort on top of the in-app socket updates.
 */
export async function sendPush(ownerType, ownerId, payload) {
  const { rows } = await query(
    'SELECT id, subscription FROM push_subscriptions WHERE owner_type = $1 AND owner_id = $2',
    [ownerType, ownerId]
  );
  const body = JSON.stringify(payload);
  await Promise.all(
    rows.map(async (row) => {
      try {
        await webpush.sendNotification(row.subscription, body);
      } catch (err) {
        if (err.statusCode === 410 || err.statusCode === 404) {
          await query('DELETE FROM push_subscriptions WHERE id = $1', [row.id]);
        } else {
          console.warn(`Push to ${ownerType} ${ownerId} failed:`, err.message);
        }
      }
    })
  );
}
