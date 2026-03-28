import { Redis } from '@upstash/redis';

const kv = new Redis({
  url: process.env.UPSTASH_REDIS_REST_URL,
  token: process.env.UPSTASH_REDIS_REST_TOKEN,
});

const FB_CRAWLER_UA = 'facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)';
const IG_APP_ID = '936619743392459';

// --- Scraper ---
async function fetchProfile(username) {
  // Strategy 1: Facebook crawler UA (whitelisted by Instagram)
  try {
    const result = await scrapeHTML(username);
    if (result) return result;
  } catch (e) { /* fall through */ }

  // Strategy 2: Instagram mobile API
  try {
    return await mobileAPI(username);
  } catch (e) {
    throw new Error(`All methods failed for @${username}: ${e.message}`);
  }
}

async function scrapeHTML(username) {
  const res = await fetch(`https://www.instagram.com/${username}/`, {
    headers: { 'User-Agent': FB_CRAWLER_UA },
    redirect: 'follow',
  });
  if (!res.ok) return null;

  const html = await res.text();
  if (res.url?.includes('/accounts/login') || html.includes('/accounts/login')) return null;

  const ogMatch = html.match(/<meta\s+property="og:description"\s+content="([^"]+)"/i)
    || html.match(/<meta\s+content="([^"]+)"\s+property="og:description"/i);
  if (!ogMatch) return null;

  const m = ogMatch[1].match(/([\d,\.]+[KMB]?)\s+Followers?,\s*([\d,\.]+[KMB]?)\s+Following,\s*([\d,\.]+[KMB]?)\s+Posts?/i);
  if (!m) return null;

  return { username, followers: parseCount(m[1]), following: parseCount(m[2]), posts: parseCount(m[3]) };
}

async function mobileAPI(username) {
  const res = await fetch(
    `https://i.instagram.com/api/v1/users/web_profile_info/?username=${encodeURIComponent(username)}`,
    { headers: { 'User-Agent': 'Instagram 275.0.0.27.98 Android', 'X-IG-App-ID': IG_APP_ID } }
  );
  if (!res.ok) throw new Error(`HTTP ${res.status}`);

  const user = (await res.json())?.data?.user;
  if (!user) throw new Error('User not found');

  return {
    username: user.username || username,
    followers: user.edge_followed_by?.count ?? 0,
    following: user.edge_follow?.count ?? 0,
    posts: user.edge_owner_to_timeline_media?.count ?? 0,
  };
}

function parseCount(str) {
  const cleaned = str.replace(/,/g, '');
  const upper = cleaned.toUpperCase();
  if (upper.endsWith('K')) return Math.round(parseFloat(upper) * 1_000);
  if (upper.endsWith('M')) return Math.round(parseFloat(upper) * 1_000_000);
  if (upper.endsWith('B')) return Math.round(parseFloat(upper) * 1_000_000_000);
  return parseInt(cleaned, 10) || 0;
}

// --- Notification ---
async function sendNotification(title, message) {
  const topic = process.env.NTFY_TOPIC;
  if (!topic) throw new Error('NTFY_TOPIC not set');

  await fetch(`https://ntfy.sh/${topic}`, {
    method: 'POST',
    headers: { Title: title, Priority: 'high', Tags: 'chart_with_upwards_trend' },
    body: message,
  });
}

function fmt(n) {
  if (n >= 1_000_000) return (n / 1_000_000).toFixed(1) + 'M';
  if (n >= 10_000) return (n / 1_000).toFixed(1) + 'K';
  return n.toLocaleString();
}

// --- Main ---
const usernames = (process.env.INSTAGRAM_USERNAMES || '')
  .split(',').map(u => u.trim().toLowerCase()).filter(Boolean);

if (usernames.length === 0) {
  console.log('No usernames configured');
  process.exit(0);
}

for (const username of usernames) {
  try {
    console.log(`Checking @${username}...`);
    const profile = await fetchProfile(username);
    console.log(`  Followers: ${profile.followers}, Following: ${profile.following}, Posts: ${profile.posts}`);

    const key = `ig:${username}`;
    const stored = await kv.get(key);

    if (stored) {
      const changes = [];
      if (profile.followers !== stored.followers) {
        const d = profile.followers - stored.followers;
        changes.push(`Followers: ${fmt(stored.followers)} → ${fmt(profile.followers)} (${d > 0 ? '+' : ''}${d})`);
      }
      if (profile.following !== stored.following) {
        const d = profile.following - stored.following;
        changes.push(`Following: ${fmt(stored.following)} → ${fmt(profile.following)} (${d > 0 ? '+' : ''}${d})`);
      }

      if (changes.length > 0) {
        console.log(`  CHANGED! Sending notification...`);
        await sendNotification(`@${username} changed!`, changes.join('\n'));
      } else {
        console.log(`  No changes.`);
      }
    } else {
      console.log(`  First check, storing baseline.`);
    }

    await kv.set(key, {
      followers: profile.followers,
      following: profile.following,
      posts: profile.posts,
      lastChecked: new Date().toISOString(),
    });
  } catch (err) {
    console.error(`  Error: ${err.message}`);
  }
}
