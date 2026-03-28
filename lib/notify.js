export async function sendBrrrNotification(title, message) {
  const secret = process.env.BRRR_SECRET;
  if (!secret) throw new Error('BRRR_SECRET not set');

  const res = await fetch(`https://api.brrr.now/v1/${secret}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      title,
      message,
      sound: 'upbeat_bells',
    }),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`brrr API error ${res.status}: ${text}`);
  }
}

export function formatChange(username, oldData, newData) {
  const changes = [];

  if (newData.followers !== oldData.followers) {
    const delta = newData.followers - oldData.followers;
    const sign = delta > 0 ? '+' : '';
    changes.push(`Followers: ${fmt(oldData.followers)} → ${fmt(newData.followers)} (${sign}${delta})`);
  }

  if (newData.following !== oldData.following) {
    const delta = newData.following - oldData.following;
    const sign = delta > 0 ? '+' : '';
    changes.push(`Following: ${fmt(oldData.following)} → ${fmt(newData.following)} (${sign}${delta})`);
  }

  if (changes.length === 0) return null;

  return {
    title: `📊 @${username} changed!`,
    message: changes.join('\n'),
  };
}

function fmt(n) {
  if (n >= 1_000_000) return (n / 1_000_000).toFixed(1) + 'M';
  if (n >= 10_000) return (n / 1_000).toFixed(1) + 'K';
  return n.toLocaleString();
}
