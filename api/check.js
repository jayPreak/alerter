import { Redis } from '@upstash/redis';

const kv = Redis.fromEnv();
import { fetchProfile } from '../lib/scraper.js';
import { sendNotification, formatChange } from '../lib/notify.js';

export default async function handler(req, res) {
  const usernames = (process.env.INSTAGRAM_USERNAMES || '')
    .split(',')
    .map((u) => u.trim().toLowerCase())
    .filter(Boolean);

  if (usernames.length === 0) {
    return res.status(400).json({ error: 'INSTAGRAM_USERNAMES not set' });
  }

  const results = [];

  for (const username of usernames) {
    try {
      const profile = await fetchProfile(username);
      const key = `ig:${username}`;
      const stored = await kv.get(key);

      let changed = false;
      let notification = null;

      if (stored) {
        notification = formatChange(username, stored, profile);
        if (notification) {
          changed = true;
          await sendNotification(notification.title, notification.message);
        }
      }

      // Save current counts
      await kv.set(key, {
        followers: profile.followers,
        following: profile.following,
        posts: profile.posts,
        lastChecked: new Date().toISOString(),
      });

      results.push({
        username,
        followers: profile.followers,
        following: profile.following,
        posts: profile.posts,
        changed,
        notified: !!notification,
      });
    } catch (err) {
      results.push({ username, error: err.message });
    }
  }

  return res.status(200).json({ checked: new Date().toISOString(), results });
}
