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
const format = (args.get("format") || "wav").toLowerCase();
const linesPath = path.join(root, args.get("lines") || "narakeet-lines.csv");
const overwrite = args.has("overwrite");
const pollIntervalMs = Number(args.get("poll-interval-ms") || 5000);

if (!apiKey) {
  throw new Error("Set NARAKEET_API_KEY before generating audio.");
}

if (/^(tu-api-key|your-api-key|api-key|changeme|replace-me)$/i.test(apiKey.trim())) {
  throw new Error("NARAKEET_API_KEY still contains a placeholder. Set it to your real Narakeet API key.");
}

if (!["wav", "mp3"].includes(format)) {
  throw new Error(`Unsupported format: ${format}. Use wav or mp3.`);
}

if (!Number.isFinite(pollIntervalMs) || pollIntervalMs < 1000) {
  throw new Error("--poll-interval-ms must be a number greater than or equal to 1000.");
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

function targetName(file, outputFormat) {
  const extension = `.${outputFormat.toLowerCase()}`;
  const parsed = path.parse(file);
  if ([".mp3", ".wav"].includes(parsed.ext.toLowerCase())) {
    return `${parsed.name}${extension}`;
  }
  return `${file}${extension}`;
}

async function exists(file) {
  try {
    await access(file);
    return true;
  } catch {
    return false;
  }
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function textResponse(response) {
  return response.text().catch(() => "");
}

async function requestStreamingAudio(url, text, outputLabel) {
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
    const body = await textResponse(response);
    throw new Error(
      `Narakeet request failed for ${outputLabel}: HTTP ${response.status} ${response.statusText}${body ? ` - ${body}` : ""}`,
    );
  }

  return Buffer.from(await response.arrayBuffer());
}

async function requestPollingAudio(url, text, outputLabel) {
  const request = await fetch(url, {
    method: "POST",
    headers: {
      "content-type": "text/plain; charset=utf-8",
      "x-api-key": apiKey,
    },
    body: text,
  });

  if (!request.ok) {
    const body = await textResponse(request);
    throw new Error(
      `Narakeet build request failed for ${outputLabel}: HTTP ${request.status} ${request.statusText}${body ? ` - ${body}` : ""}`,
    );
  }

  const build = await request.json();
  if (!build.statusUrl) {
    throw new Error(`Narakeet build request for ${outputLabel} did not return a statusUrl.`);
  }

  while (true) {
    await sleep(pollIntervalMs);

    const statusResponse = await fetch(build.statusUrl);
    if (!statusResponse.ok) {
      const body = await textResponse(statusResponse);
      throw new Error(
        `Narakeet status check failed for ${outputLabel}: HTTP ${statusResponse.status} ${statusResponse.statusText}${body ? ` - ${body}` : ""}`,
      );
    }

    const status = await statusResponse.json();
    const percent = Number.isFinite(status.percent) ? ` ${status.percent}%` : "";
    console.log(`  status:${percent}${status.finished ? " finished" : ""}`);

    if (!status.finished) {
      continue;
    }

    if (!status.succeeded) {
      throw new Error(`Narakeet build failed for ${outputLabel}: ${status.message || "unknown error"}`);
    }

    if (!status.result) {
      throw new Error(`Narakeet build succeeded for ${outputLabel} but did not return a result URL.`);
    }

    const audio = await fetch(status.result);
    if (!audio.ok) {
      const body = await textResponse(audio);
      throw new Error(
        `Narakeet download failed for ${outputLabel}: HTTP ${audio.status} ${audio.statusText}${body ? ` - ${body}` : ""}`,
      );
    }

    return Buffer.from(await audio.arrayBuffer());
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
  const outputFile = targetName(file, format);
  const targetFile = path.join(targetDir, outputFile);

  await mkdir(targetDir, { recursive: true });

  if (!overwrite && (await exists(targetFile))) {
    console.log(`Skipping existing: ${intent}/${outputFile}`);
    continue;
  }

  const url = new URL(`https://api.narakeet.com/text-to-speech/${format}`);
  url.searchParams.set("voice", voice);

  console.log(`Generating: ${intent}/${outputFile}`);
  const outputLabel = `${intent}/${outputFile}`;
  const bytes =
    format === "wav"
      ? await requestPollingAudio(url, text, outputLabel)
      : await requestStreamingAudio(url, text, outputLabel);

  await writeFile(targetFile, bytes);
}
