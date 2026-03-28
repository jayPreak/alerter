import { Redis } from '@upstash/redis';

const kv = Redis.fromEnv();

export default async function handler(req, res) {
  const usernames = (process.env.INSTAGRAM_USERNAMES || '')
    .split(',')
    .map((u) => u.trim().toLowerCase())
    .filter(Boolean);

  if (usernames.length === 0) {
    return res.status(400).json({ error: 'INSTAGRAM_USERNAMES not set' });
  }

  const accounts = [];

  for (const username of usernames) {
    const data = await kv.get(`ig:${username}`);
    accounts.push({ username, ...data });
  }

  return res.status(200).json({ accounts });
}
