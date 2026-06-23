import fs from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";

const sidecarRoot =
  process.env.DOCUMENT_SIDECAR_HOME ||
  "C:\\Users\\NeoSol\\AppData\\Local\\Programs\\Document Sidecar";
const rhwpPublicDir = path.join(
  sidecarRoot,
  "resources",
  "server",
  "public",
  "rhwp-studio",
);
const bundleJsCandidates = fs.existsSync(path.join(rhwpPublicDir, "assets"))
  ? fs
      .readdirSync(path.join(rhwpPublicDir, "assets"), { withFileTypes: true })
      .filter((entry) => entry.isFile() && /^index-.*\.js$/i.test(entry.name))
      .map((entry) => path.join(rhwpPublicDir, "assets", entry.name))
  : [];
const standaloneJs = path.join(rhwpPublicDir, "rhwp.js");
const sourceWasmCandidates = [
  ...fs
    .readdirSync(path.join(rhwpPublicDir, "assets"), { withFileTypes: true })
    .filter((entry) => entry.isFile() && /^rhwp_bg.*\.wasm$/i.test(entry.name))
    .map((entry) => path.join(rhwpPublicDir, "assets", entry.name)),
  path.join(rhwpPublicDir, "rhwp_bg.wasm"),
  path.join(sidecarRoot, "resources", "server", "public", "rhwp_bg.wasm"),
];
const cacheDir = path.join(process.cwd(), ".sidekick-rhwp-cache");
const cachedJs = path.join(cacheDir, "rhwp.mjs");
const cachedWasm = path.join(cacheDir, "rhwp_bg.wasm");

function usage() {
  console.log(`Usage:
  node tools/rhwp-inspect.mjs <hwp-or-hwpx-path> [options]

Options:
  --search <text>       Search the document, including table cells.
  --replace <text>      Text to replace.
  --with <text>         Replacement text.
  --out <path>          Output path for replaced/exported HWP.
  --json                Print compact JSON only.
`);
}

function readArgs(argv) {
  const args = { file: null, search: null, replace: null, with: null, out: null, json: false };
  for (let i = 0; i < argv.length; i += 1) {
    const value = argv[i];
    if (value === "--search") args.search = argv[++i];
    else if (value === "--replace") args.replace = argv[++i];
    else if (value === "--with") args.with = argv[++i];
    else if (value === "--out") args.out = argv[++i];
    else if (value === "--json") args.json = true;
    else if (!args.file) args.file = value;
    else throw new Error(`Unknown argument: ${value}`);
  }
  return args;
}

function ensureRhwpCache() {
  const sourceWasm = sourceWasmCandidates.find((candidate) => fs.existsSync(candidate));
  const sourceJs = bundleJsCandidates.find((candidate) => fs.existsSync(candidate)) || standaloneJs;
  if (!fs.existsSync(sourceJs) || !sourceWasm) {
    throw new Error(`rhwp runtime not found under: ${rhwpPublicDir}`);
  }
  fs.mkdirSync(cacheDir, { recursive: true });
  const jsNeedsCopy =
    !fs.existsSync(cachedJs) ||
    fs.statSync(cachedJs).mtimeMs < fs.statSync(sourceJs).mtimeMs;
  const wasmNeedsCopy =
    !fs.existsSync(cachedWasm) ||
    fs.statSync(cachedWasm).mtimeMs < fs.statSync(sourceWasm).mtimeMs;
  if (jsNeedsCopy) {
    if (bundleJsCandidates.includes(sourceJs)) {
      const bundle = fs.readFileSync(sourceJs, "utf8");
      const start = bundle.indexOf("var e=class");
      const end = bundle.indexOf("var M=", start);
      if (start < 0 || end < 0) {
        throw new Error(`could not extract rhwp module from: ${sourceJs}`);
      }
      const glue = bundle.slice(start, end);
      fs.writeFileSync(
        cachedJs,
        `${glue}\nexport { e as HwpDocument, t as HwpViewer, j as default, n as version };\n`,
      );
    } else {
      fs.copyFileSync(sourceJs, cachedJs);
    }
  }
  if (wasmNeedsCopy) fs.copyFileSync(sourceWasm, cachedWasm);
}

function parseJsonMaybe(text) {
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
}

function defaultOutputPath(input) {
  const parsed = path.parse(input);
  return path.join(parsed.dir, `${parsed.name}_rhwp${parsed.ext || ".hwp"}`);
}

const args = readArgs(process.argv.slice(2));
if (!args.file) {
  usage();
  process.exit(2);
}

ensureRhwpCache();

const rhwp = await import(pathToFileURL(cachedJs).href);
const wasmBytes = fs.readFileSync(cachedWasm);
await rhwp.default(wasmBytes);

const inputPath = path.resolve(args.file);
const inputBytes = fs.readFileSync(inputPath);
const doc = new rhwp.HwpDocument(inputBytes);

const result = {
  ok: true,
  input: inputPath,
  rhwpVersion: typeof rhwp.version === "function" ? rhwp.version() : null,
  pageCount: typeof doc.pageCount === "function" ? doc.pageCount() : null,
  documentInfo: parseJsonMaybe(doc.getDocumentInfo()),
};

if (args.search) {
  result.search = {
    query: args.search,
    matches: parseJsonMaybe(doc.searchAllText(args.search, false, true)),
  };
}

if (args.replace !== null && args.replace !== undefined) {
  if (args.with === null || args.with === undefined) {
    throw new Error("--replace requires --with");
  }
  result.replace = parseJsonMaybe(doc.replaceAll(args.replace, args.with, false));
  const outPath = path.resolve(args.out || defaultOutputPath(inputPath));
  fs.writeFileSync(outPath, doc.exportHwp());
  result.output = outPath;
  result.exportVerify = parseJsonMaybe(doc.exportHwpVerify());
}

if (typeof doc.free === "function") doc.free();

if (args.json) {
  console.log(JSON.stringify(result));
} else {
  console.log(JSON.stringify(result, null, 2));
}
