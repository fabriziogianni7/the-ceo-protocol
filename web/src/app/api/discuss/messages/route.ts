import { NextRequest, NextResponse } from "next/server";
import { buildCommentTree, createMessage, listMessagesByTab } from "@/lib/discuss/store";

export const dynamic = "force-dynamic";

export async function GET(request: NextRequest): Promise<NextResponse> {
  const tab = request.nextUrl.searchParams.get("tab");
  if (!tab) {
    return NextResponse.json({ error: "Missing tab query param" }, { status: 400 });
  }

  try {
    const messages = await listMessagesByTab(tab);
    const comments = buildCommentTree(messages);
    return NextResponse.json({ comments }, { status: 200 });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Failed to list messages";
    return NextResponse.json({ error: message }, { status: 400 });
  }
}

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
    isAgent?: boolean;
    isSystem?: boolean;
  };

  try {
    const message = await createMessage({
      tab: payload.tab ?? "",
      content: payload.content ?? "",
      parentId: payload.parentId ?? null,
      author: payload.author,
      isAgent: payload.isAgent,
      isSystem: payload.isSystem,
    });

    return NextResponse.json({ message }, { status: 201 });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Failed to create message";
    return NextResponse.json({ error: message }, { status: 400 });
  }
}
