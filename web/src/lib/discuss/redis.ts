import { Redis } from "@upstash/redis";

let _redis: Redis | null = null;

function _getRequiredEnv(name: "UPSTASH_REDIS_REST_URL" | "UPSTASH_REDIS_REST_TOKEN"): string {
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
    url: _getRequiredEnv("UPSTASH_REDIS_REST_URL"),
    token: _getRequiredEnv("UPSTASH_REDIS_REST_TOKEN"),
  });

  return _redis;
}
