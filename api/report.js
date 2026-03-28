import { Redis } from '@upstash/redis';
import { sendNotification, formatChange } from '../lib/notify.js';

const kv = Redis.fromEnv();

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'POST only' });
  }

  // Simple auth
  const key = req.query.key;
  if (!key || key !== process.env.REPORT_KEY) {
    return res.status(401).json({ error: 'Invalid key' });
  }

  const { username, followers, following, posts } = req.body || {};

  if (!username || followers == null || following == null) {
    return res.status(400).json({ error: 'Missing username, followers, or following' });
  }

  const redisKey = `ig:${username.toLowerCase()}`;
  const stored = await kv.get(redisKey);

  let changed = false;
  let notified = false;

  if (stored) {
    const notification = formatChange(username, stored, { followers, following });
    if (notification) {
      changed = true;
      try {
        await sendNotification(notification.title, notification.message);
        notified = true;
      } catch (e) {
        console.error('Notification failed:', e.message);
      }
    }
  }

  // Store current counts
  await kv.set(redisKey, {
    followers,
    following,
    posts: posts || 0,
    lastChecked: new Date().toISOString(),
  });

  return res.status(200).json({
    username,
    followers,
    following,
    changed,
    notified,
    firstCheck: !stored,
  });
}
