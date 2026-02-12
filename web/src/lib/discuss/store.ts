import { randomUUID } from "node:crypto";
import { getDiscussRedis } from "@/lib/discuss/redis";

export const DISCUSS_TABS = ["discussion"] as const;
export type DiscussTab = (typeof DISCUSS_TABS)[number];

type DiscussEventType =
  | "proposal"
  | "voted"
  | "executed"
  | "settled"
  | "feeAccrued"
  | "feeConverted"
  | "feesWithdrawn";

export interface DiscussMessage {
  id: string;
  tab: DiscussTab;
  parentId: string | null;
  author: string;
  content: string;
  isAgent: boolean;
  isSystem: boolean;
  eventType?: DiscussEventType;
  onchainRef?: string;
  createdAt: string;
  upvotes: number;
  downvotes: number;
}

export interface DiscussComment {
  id: string;
  author: string;
  content: string;
  timestamp: string;
  upvotes: number;
  downvotes: number;
  replies: DiscussComment[];
  isAgent?: boolean;
  isSystem?: boolean;
  eventType?: DiscussEventType;
  onchainRef?: string;
}

export interface CreateDiscussMessageInput {
  tab: string;
  content: string;
  parentId?: string | null;
  author?: string;
  isAgent?: boolean;
  isSystem?: boolean;
  eventType?: DiscussEventType;
  onchainRef?: string;
}

const MESSAGE_MAX_LENGTH = 2000;

function _getMessageKey(messageId: string): string {
  return `discuss:msg:${messageId}`;
}

function _getTabIndexKey(tab: DiscussTab): string {
  return `discuss:${tab}:ids`;
}

function _parseMessage(raw: unknown): DiscussMessage | null {
  if (!raw) return null;

  // Upstash may return auto-deserialized JSON objects.
  if (typeof raw === "object") {
    const maybe = raw as Partial<DiscussMessage>;
    if (
      typeof maybe.id === "string" &&
      typeof maybe.tab === "string" &&
      typeof maybe.author === "string" &&
      typeof maybe.content === "string" &&
      typeof maybe.createdAt === "string"
    ) {
      return {
        id: maybe.id,
        tab: maybe.tab as DiscussTab,
        parentId: maybe.parentId ?? null,
        author: maybe.author,
        content: maybe.content,
        isAgent: Boolean(maybe.isAgent),
        isSystem: Boolean(maybe.isSystem),
        eventType: maybe.eventType,
        onchainRef: maybe.onchainRef,
        createdAt: maybe.createdAt,
        upvotes: Number(maybe.upvotes ?? 0),
        downvotes: Number(maybe.downvotes ?? 0),
      };
    }
    return null;
  }

  if (typeof raw === "string") {
    try {
      return JSON.parse(raw) as DiscussMessage;
    } catch {
      return null;
    }
  }

  return null;
}

function _toRelativeTimestamp(createdAtIso: string): string {
  const createdAtMs = Date.parse(createdAtIso);
  if (Number.isNaN(createdAtMs)) {
    return "now";
  }

  const elapsedMs = Math.max(0, Date.now() - createdAtMs);
  const elapsedMinutes = Math.floor(elapsedMs / 60000);

  if (elapsedMinutes < 1) return "now";
  if (elapsedMinutes < 60) return `${elapsedMinutes}m`;

  const elapsedHours = Math.floor(elapsedMinutes / 60);
  if (elapsedHours < 24) return `${elapsedHours}h`;

  const elapsedDays = Math.floor(elapsedHours / 24);
  return `${elapsedDays}d`;
}

function _messageToComment(message: DiscussMessage): DiscussComment {
  return {
    id: message.id,
    author: message.author,
    content: message.content,
    timestamp: _toRelativeTimestamp(message.createdAt),
    upvotes: message.upvotes,
    downvotes: message.downvotes,
    replies: [],
    isAgent: message.isAgent,
    isSystem: message.isSystem,
    eventType: message.eventType,
    onchainRef: message.onchainRef,
  };
}

export function isDiscussTab(tab: string): tab is DiscussTab {
  return (DISCUSS_TABS as readonly string[]).includes(tab);
}

export async function createMessage(input: CreateDiscussMessageInput): Promise<DiscussMessage> {
  const tab = input.tab?.trim();
  if (!tab || !isDiscussTab(tab)) {
    throw new Error("Invalid tab");
  }

  const content = input.content?.trim();
  if (!content) {
    throw new Error("Content is required");
  }
  if (content.length > MESSAGE_MAX_LENGTH) {
    throw new Error(`Content exceeds max length of ${MESSAGE_MAX_LENGTH}`);
  }

  const parentId = input.parentId ? String(input.parentId) : null;
  const author = input.author?.trim() || "Anonymous";
  const createdAt = new Date().toISOString();
  const id = randomUUID();
  const redis = getDiscussRedis();

  if (parentId) {
    const parentRaw = await redis.get(_getMessageKey(parentId));
    const parent = _parseMessage(parentRaw);
    if (!parent) {
      throw new Error("Parent comment not found");
    }
    if (parent.tab !== tab) {
      throw new Error("Parent comment tab mismatch");
    }
  }

  const message: DiscussMessage = {
    id,
    tab,
    parentId,
    author,
    content,
    isAgent: Boolean(input.isAgent),
    isSystem: Boolean(input.isSystem),
    eventType: input.eventType,
    onchainRef: input.onchainRef?.trim() || undefined,
    createdAt,
    upvotes: 0,
    downvotes: 0,
  };

  await redis.set(_getMessageKey(id), JSON.stringify(message));
  await redis.zadd(_getTabIndexKey(tab), { score: Date.now(), member: id });

  return message;
}

export async function listMessagesByTab(tab: string): Promise<DiscussMessage[]> {
  if (!isDiscussTab(tab)) {
    throw new Error("Invalid tab");
  }

  const redis = getDiscussRedis();
  const ids = await redis.zrange<string[]>(_getTabIndexKey(tab), 0, -1);
  if (!ids || ids.length === 0) {
    return [];
  }

  const raws = await Promise.all(ids.map((id) => redis.get(_getMessageKey(id))));
  const messages = raws
    .map((raw) => _parseMessage(raw))
    .filter((msg): msg is DiscussMessage => Boolean(msg))
    .sort((a, b) => Date.parse(b.createdAt) - Date.parse(a.createdAt));

  return messages;
}

export function buildCommentTree(flatMessages: DiscussMessage[]): DiscussComment[] {
  const commentsById = new Map<string, DiscussComment>();
  const childrenByParent = new Map<string, DiscussComment[]>();
  const roots: DiscussComment[] = [];

  for (const message of flatMessages) {
    commentsById.set(message.id, _messageToComment(message));
  }

  for (const message of flatMessages) {
    const comment = commentsById.get(message.id);
    if (!comment) continue;

    if (!message.parentId) {
      roots.push(comment);
      continue;
    }

    const siblings = childrenByParent.get(message.parentId) ?? [];
    siblings.push(comment);
    childrenByParent.set(message.parentId, siblings);
  }

  const attachReplies = (comment: DiscussComment): DiscussComment => {
    const replies = childrenByParent.get(comment.id) ?? [];
    comment.replies = replies.map((reply) => attachReplies(reply));
    return comment;
  };

  return roots.map((root) => attachReplies(root));
}
