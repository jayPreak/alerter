export async function sendNotification(title, message) {
  const topic = process.env.NTFY_TOPIC;
  if (!topic) throw new Error('NTFY_TOPIC not set');

  const res = await fetch(`https://ntfy.sh/${topic}`, {
    method: 'POST',
    headers: {
      Title: title,
      Priority: 'high',
      Tags: 'chart_with_upwards_trend',
    },
    body: message,
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`ntfy error ${res.status}: ${text}`);
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
    title: `@${username} changed!`,
    message: changes.join('\n'),
  };
}

function fmt(n) {
  if (n >= 1_000_000) return (n / 1_000_000).toFixed(1) + 'M';
  if (n >= 10_000) return (n / 1_000).toFixed(1) + 'K';
  return n.toLocaleString();
}
