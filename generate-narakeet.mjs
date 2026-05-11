import { mkdir, readFile, writeFile, access } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.dirname(fileURLToPath(import.meta.url));

const args = new Map();
for (let i = 2; i < process.argv.length; i += 1) {
  const arg = process.argv[i];
  if (arg === "--overwrite") {
    args.set("overwrite", true);
  } else if (arg.startsWith("--")) {
    args.set(arg.slice(2), process.argv[i + 1]);
    i += 1;
  }
}

const apiKey = args.get("api-key") || process.env.NARAKEET_API_KEY;
const voice = args.get("voice") || "alejandra";
const format = args.get("format") || "mp3";
const linesPath = path.join(root, args.get("lines") || "narakeet-lines.csv");
const overwrite = args.has("overwrite");

if (!apiKey) {
  throw new Error("Set NARAKEET_API_KEY before generating audio.");
}

function parseCsv(input) {
  const rows = [];
  let row = [];
  let field = "";
  let quoted = false;

  for (let i = 0; i < input.length; i += 1) {
    const char = input[i];
    const next = input[i + 1];

    if (quoted) {
      if (char === '"' && next === '"') {
        field += '"';
        i += 1;
      } else if (char === '"') {
        quoted = false;
      } else {
        field += char;
      }
    } else if (char === '"') {
      quoted = true;
    } else if (char === ",") {
      row.push(field);
      field = "";
    } else if (char === "\n") {
      row.push(field.replace(/\r$/, ""));
      rows.push(row);
      row = [];
      field = "";
    } else {
      field += char;
    }
  }

  if (field || row.length) {
    row.push(field.replace(/\r$/, ""));
    rows.push(row);
  }

  const [header, ...data] = rows;
  return data
    .filter((values) => values.some(Boolean))
    .map((values) =>
      Object.fromEntries(header.map((key, index) => [key, values[index] || ""])),
    );
}

async function exists(file) {
  try {
    await access(file);
    return true;
  } catch {
    return false;
  }
}

const lines = parseCsv(await readFile(linesPath, "utf8"));

for (const line of lines) {
  const intent = line.intent?.trim();
  const file = line.file?.trim();
  const text = line.text?.trim();

  if (!intent || !file || !text) {
    console.warn("Skipping incomplete row.");
    continue;
  }

  const targetDir = path.join(root, intent);
  const targetFile = path.join(targetDir, file);

  await mkdir(targetDir, { recursive: true });

  if (!overwrite && (await exists(targetFile))) {
    console.log(`Skipping existing: ${intent}/${file}`);
    continue;
  }

  const url = new URL(`https://api.narakeet.com/text-to-speech/${format}`);
  url.searchParams.set("voice", voice);

  console.log(`Generating: ${intent}/${file}`);
  const response = await fetch(url, {
    method: "POST",
    headers: {
      accept: "application/octet-stream",
      "content-type": "text/plain; charset=utf-8",
      "x-api-key": apiKey,
    },
    body: text,
  });

  if (!response.ok) {
    const body = await response.text().catch(() => "");
    throw new Error(
      `Narakeet request failed for ${intent}/${file}: HTTP ${response.status} ${response.statusText}${body ? ` - ${body}` : ""}`,
    );
  }

  const bytes = Buffer.from(await response.arrayBuffer());
  await writeFile(targetFile, bytes);
}
