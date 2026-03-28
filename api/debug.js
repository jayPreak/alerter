import { fetchProfile } from '../lib/scraper.js';

export default async function handler(req, res) {
  const username = req.query.user || 'jaypreak8';
  try {
    const profile = await fetchProfile(username);
    res.status(200).json({ ok: true, profile });
  } catch (e) {
    res.status(500).json({ ok: false, error: e.message });
  }
}
