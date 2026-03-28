export default function handler(req, res) {
  res.status(200).json({
    status: 'running',
    message: '👀 InstaAlerter is alive!',
    endpoints: {
      check: '/api/check',
      status: '/api/status',
    },
  });
}
