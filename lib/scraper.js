const IG_APP_ID = '936619743392459';
const USER_AGENT = 'Instagram 275.0.0.27.98 Android';

export async function fetchProfile(username) {
  const clean = username.toLowerCase().trim();

  // Use Instagram's web profile info API (no auth needed)
  const url = `https://i.instagram.com/api/v1/users/web_profile_info/?username=${encodeURIComponent(clean)}`;

  const res = await fetch(url, {
    headers: {
      'User-Agent': USER_AGENT,
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
    username: user.username || clean,
    followers: user.edge_followed_by?.count ?? 0,
    following: user.edge_follow?.count ?? 0,
    posts: user.edge_owner_to_timeline_media?.count ?? 0,
    isPrivate: user.is_private ?? false,
    fullName: user.full_name || '',
  };
}
