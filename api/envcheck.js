export default function handler(req, res) {
  res.status(200).json({
    hasReportKey: !!process.env.REPORT_KEY,
    reportKeyLength: process.env.REPORT_KEY?.length || 0,
    hasRedisUrl: !!process.env.UPSTASH_REDIS_REST_URL,
    hasRedisToken: !!process.env.UPSTASH_REDIS_REST_TOKEN,
    hasNtfyTopic: !!process.env.NTFY_TOPIC,
  });
}
