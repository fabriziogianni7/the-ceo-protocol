import { formatUnits, isAddress, parseUnits, type Address } from "viem";

export function formatAmount(value: bigint | undefined, decimals = 6, precision = 4): string {
  if (value === undefined) return "0";
  const asNumber = Number(formatUnits(value, decimals));
  if (!Number.isFinite(asNumber)) {
    return formatUnits(value, decimals);
  }
  return asNumber.toLocaleString(undefined, { maximumFractionDigits: precision });
}

export function parseAmount(value: string, decimals = 6): bigint {
  const sanitized = value.trim();
  if (!sanitized) return BigInt(0);
  return parseUnits(sanitized, decimals);
}

export function shortenAddress(address?: Address): string {
  if (!address) return "-";
  return `${address.slice(0, 6)}...${address.slice(-4)}`;
}

export function isValidAddress(value: string): value is Address {
  return isAddress(value);
}
