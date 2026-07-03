import { Router } from 'express';
import { requireAuth } from '../middleware/auth.js';
import { saveSubscription, vapidPublicKey } from '../services/push.js';

const router = Router();

router.get('/vapid-public-key', (req, res) => {
  res.json({ publicKey: vapidPublicKey });
});

router.post('/subscribe', requireAuth, async (req, res) => {
  const subscription = req.body?.subscription;
  if (!subscription?.endpoint) {
    return res.status(400).json({ error: 'Invalid subscription' });
  }
  await saveSubscription(req.user.role, req.user.id, subscription);
  res.status(201).json({ ok: true });
});

export default router;
