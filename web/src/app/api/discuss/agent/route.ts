import { NextRequest, NextResponse } from "next/server";
import { createMessage } from "@/lib/discuss/store";

export const dynamic = "force-dynamic";

export async function POST(request: NextRequest): Promise<NextResponse> {
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: "Invalid JSON body" }, { status: 400 });
  }

  if (!body || typeof body !== "object") {
    return NextResponse.json({ error: "Invalid payload" }, { status: 400 });
  }

  const payload = body as {
    tab?: string;
    content?: string;
    parentId?: string | null;
    author?: string;
    eventType?:
      | "proposal"
      | "voted"
      | "executed"
      | "settled"
      | "feeAccrued"
      | "feeConverted"
      | "feesWithdrawn";
    onchainRef?: string;
  };

  try {
    const message = await createMessage({
      tab: payload.tab ?? "",
      content: payload.content ?? "",
      parentId: payload.parentId ?? null,
      author: payload.author ?? "agent",
      isAgent: true,
      eventType: payload.eventType,
      onchainRef: payload.onchainRef,
    });

    return NextResponse.json({ message }, { status: 201 });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Failed to create agent message";
    return NextResponse.json({ error: message }, { status: 400 });
  }
}
