const USER_AGENT =
  'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1';

export async function fetchProfile(username) {
  const clean = username.toLowerCase().trim();
  const url = `https://www.instagram.com/${clean}/`;

  const res = await fetch(url, {
    headers: {
      'User-Agent': USER_AGENT,
      Accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.9',
    },
  });

  if (res.status === 404) throw new Error('Profile not found');
  if (res.status === 429) throw new Error('Rate limited');
  if (!res.ok) throw new Error(`HTTP ${res.status}`);

  const html = await res.text();
  return parseHTML(html, clean);
}

function parseHTML(html, username) {
  // Try meta description: "X Followers, Y Following, Z Posts"
  const metaMatch = html.match(
    /<meta\s+(?:name="description"|property="og:description")\s+content="([^"]+)"/i
  );
  if (metaMatch) {
    const result = extractCounts(metaMatch[1], username);
    if (result) return result;
  }

  // Attribute order can differ
  const ogMatch = html.match(
    /<meta\s+content="([^"]+)"\s+property="og:description"/i
  );
  if (ogMatch) {
    const result = extractCounts(ogMatch[1], username);
    if (result) return result;
  }

  // Try embedded JSON
  const jsonResult = parseEmbeddedJSON(html, username);
  if (jsonResult) return jsonResult;

  throw new Error('Could not parse profile. Account may be private.');
}

function extractCounts(text, username) {
  const match = text.match(
    /([\d,\.]+[KMB]?)\s+Followers?,\s*([\d,\.]+[KMB]?)\s+Following,\s*([\d,\.]+[KMB]?)\s+Posts?/i
  );
  if (!match) return null;

  return {
    username,
    followers: parseCount(match[1]),
    following: parseCount(match[2]),
    posts: parseCount(match[3]),
  };
}

function parseEmbeddedJSON(html, username) {
  const followersMatch = html.match(/"edge_followed_by"\s*:\s*\{\s*"count"\s*:\s*(\d+)/);
  const followingMatch = html.match(/"edge_follow"\s*:\s*\{\s*"count"\s*:\s*(\d+)/);
  if (!followersMatch || !followingMatch) return null;

  const postsMatch = html.match(/"edge_owner_to_timeline_media"\s*:\s*\{\s*"count"\s*:\s*(\d+)/);

  return {
    username,
    followers: parseInt(followersMatch[1], 10),
    following: parseInt(followingMatch[1], 10),
    posts: postsMatch ? parseInt(postsMatch[1], 10) : 0,
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
