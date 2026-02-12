import { Redis } from "@upstash/redis";

let _redis: Redis | null = null;

function _getRequiredEnv(name: "REDIS_URL" | "KV_REST_API_TOKEN"): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

export function getDiscussRedis(): Redis {
  if (_redis) {
    return _redis;
  }

  _redis = new Redis({
    url: _getRequiredEnv("REDIS_URL"),
    token: _getRequiredEnv("KV_REST_API_TOKEN"),
  });

  return _redis;
}
