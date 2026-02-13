import { NextResponse } from "next/server";
import archiver from "archiver";
import { createReadStream, existsSync } from "node:fs";
import { join } from "node:path";
import { Writable } from "node:stream";

const SCRIPTS_DIR = join(process.cwd(), "public", "agent-scripts", "scripts");
const FILES = [
  "build-action.mjs",
  "build-proposal.mjs",
  "submit-proposal.mjs",
  "ceo-config.mjs",
  "common.mjs",
  "package.json",
  "proposal-examples/noop.json",
  "proposal-examples/deploy-morpho.json",
];

export const dynamic = "force-dynamic";

export async function GET() {
  const chunks: Buffer[] = [];
  const writable = new Writable({
    write(chunk: Buffer, _enc, cb) {
      chunks.push(chunk);
      cb();
    },
  });

  const archive = archiver("zip", { zlib: { level: 9 } });
  archive.pipe(writable);

  archive.on("error", (err) => {
    console.error("Archiver error:", err);
  });

  for (const file of FILES) {
    const filePath = join(SCRIPTS_DIR, file);
    if (existsSync(filePath)) {
      archive.append(createReadStream(filePath), { name: file });
    }
  }

  await archive.finalize();

  await new Promise<void>((resolve, reject) => {
    writable.on("finish", resolve);
    writable.on("error", reject);
  });

  const buffer = Buffer.concat(chunks);
  return new NextResponse(buffer, {
    headers: {
      "Content-Type": "application/zip",
      "Content-Disposition": 'attachment; filename="ceo-proposal-scripts.zip"',
      "Content-Length": buffer.length.toString(),
    },
  });
}
