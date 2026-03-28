// Facebook's crawler UA is whitelisted by Instagram (same parent company)
const FB_CRAWLER_UA = 'facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)';
const IG_APP_ID = '936619743392459';

export async function fetchProfile(username) {
  const clean = username.toLowerCase().trim();

  // Strategy 1: HTML scrape with Facebook crawler UA
  try {
    const result = await scrapeHTML(clean);
    if (result) return result;
  } catch (e) {
    // fall through to strategy 2
  }

  // Strategy 2: Instagram mobile API
  try {
    return await mobileAPI(clean);
  } catch (e) {
    throw new Error(`All methods failed for @${clean}. Last error: ${e.message}`);
  }
}

async function scrapeHTML(username) {
  const url = `https://www.instagram.com/${username}/`;
  const res = await fetch(url, {
    headers: { 'User-Agent': FB_CRAWLER_UA },
    redirect: 'follow',
  });

  if (!res.ok) return null;

  const html = await res.text();

  // Check if redirected to login
  if (res.url?.includes('/accounts/login') || html.includes('/accounts/login')) {
    return null;
  }

  // Parse og:description: "X Followers, Y Following, Z Posts - ..."
  const ogMatch = html.match(
    /<meta\s+property="og:description"\s+content="([^"]+)"/i
  ) || html.match(
    /<meta\s+content="([^"]+)"\s+property="og:description"/i
  );

  if (!ogMatch) return null;

  const countMatch = ogMatch[1].match(
    /([\d,\.]+[KMB]?)\s+Followers?,\s*([\d,\.]+[KMB]?)\s+Following,\s*([\d,\.]+[KMB]?)\s+Posts?/i
  );
  if (!countMatch) return null;

  return {
    username,
    followers: parseCount(countMatch[1]),
    following: parseCount(countMatch[2]),
    posts: parseCount(countMatch[3]),
  };
}

async function mobileAPI(username) {
  const url = `https://i.instagram.com/api/v1/users/web_profile_info/?username=${encodeURIComponent(username)}`;
  const res = await fetch(url, {
    headers: {
      'User-Agent': 'Instagram 275.0.0.27.98 Android',
      'X-IG-App-ID': IG_APP_ID,
    },
  });

  if (res.status === 404) throw new Error('Profile not found');
  if (res.status === 429) throw new Error('Rate limited');
  if (!res.ok) throw new Error(`HTTP ${res.status}`);

  const json = await res.json();
  const user = json?.data?.user;
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
