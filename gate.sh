#!/usr/bin/env bash
set -euo pipefail

nix develop --command just build
nix develop --command just unit
nix develop --command just format-check
nix develop --command just hlint
nix build .#frontend

RIPTIDE_REPO_ROOT=$PWD nix develop .#frontend --command node <<'NODE'
const childProcess = require("node:child_process");
const crypto = require("node:crypto");
const fs = require("node:fs");
const http = require("node:http");
const net = require("node:net");
const os = require("node:os");
const path = require("node:path");

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});

async function main() {
const repoRoot = process.env.RIPTIDE_REPO_ROOT;
const frontendRoot = fs.realpathSync(path.join(repoRoot, "result"));
const port = await listenPort();
const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://127.0.0.1:${port}`);
  const name = decodeURIComponent(url.pathname === "/" ? "/index.html" : url.pathname);
  const file = path.resolve(frontendRoot, `.${name}`);
  if (!file.startsWith(`${frontendRoot}${path.sep}`) && file !== frontendRoot) {
    res.writeHead(403).end("Forbidden");
    return;
  }
  fs.readFile(file, (err, body) => {
    if (err) {
      res.writeHead(404).end("Not found");
      return;
    }
    res.writeHead(200, { "Content-Type": contentType(file) });
    res.end(body);
  });
});
const sockets = new Set();
server.on("upgrade", (req, socket) => {
  if (req.url !== "/ws") {
    socket.destroy();
    return;
  }
  const key = req.headers["sec-websocket-key"];
  if (!key) {
    socket.destroy();
    return;
  }
  const accept = crypto
    .createHash("sha1")
    .update(`${key}258EAFA5-E914-47DA-95CA-C5AB0DC85B11`)
    .digest("base64");
  socket.write([
    "HTTP/1.1 101 Switching Protocols",
    "Upgrade: websocket",
    "Connection: Upgrade",
    `Sec-WebSocket-Accept: ${accept}`,
    "",
    "",
  ].join("\r\n"));
  sockets.add(socket);
  socket.on("close", () => sockets.delete(socket));
  socket.on("error", () => sockets.delete(socket));
});

await new Promise((resolve) => server.listen(port, "127.0.0.1", resolve));

const chrome = findChrome();
const profile = fs.mkdtempSync(path.join(os.tmpdir(), "riptide-chrome-"));
const chromeProcess = childProcess.spawn(chrome, [
  "--headless=new",
  "--disable-gpu",
  "--disable-dev-shm-usage",
  "--no-first-run",
  "--no-default-browser-check",
  "--remote-debugging-port=0",
  `--user-data-dir=${profile}`,
  "about:blank",
], { stdio: ["ignore", "ignore", "pipe"] });

let stderr = "";
let devtoolsUrl;
chromeProcess.stderr.setEncoding("utf8");
chromeProcess.stderr.on("data", (chunk) => {
  stderr += chunk;
  const match = stderr.match(/DevTools listening on (ws:\/\/[^\s]+)/);
  if (match) devtoolsUrl = match[1];
});

try {
  await waitUntil(() => devtoolsUrl, 10000, "Chrome did not expose a DevTools endpoint");
  const cdp = await connectCdp(devtoolsUrl);
  const failures = [];
  cdp.on("Runtime.exceptionThrown", ({ exceptionDetails }) => {
    const exception = exceptionDetails?.exception;
    failures.push(`runtime exception: ${exception?.description || exceptionDetails?.text || "unknown"}`);
  });
  cdp.on("Runtime.consoleAPICalled", ({ type, args }) => {
    if (type !== "error") return;
    const text = args?.map((arg) => arg.value || arg.description || "").join(" ") || "console.error";
    if (!isIgnorable(text)) failures.push(`console error: ${text}`);
  });
  cdp.on("Log.entryAdded", ({ entry }) => {
    if (entry?.level !== "error") return;
    const text = [entry.url || "", entry.text || ""].join(" ");
    if (!isIgnorable(text)) failures.push(`browser log error: ${text.trim()}`);
  });

  await cdp.send("Runtime.enable");
  await cdp.send("Log.enable");
  await cdp.send("Page.enable");
  await cdp.send("Page.navigate", { url: `http://127.0.0.1:${port}/` });
  await cdp.once("Page.loadEventFired", 10000);
  const rendered = await waitForRender(cdp, failures);
  if (failures.length > 0) {
    throw new Error(failures.join("\n"));
  }
  if (!/riptide/i.test(rendered.brand)) {
    throw new Error(`missing .rt-brand text containing riptide: ${JSON.stringify(rendered.brand)}`);
  }
  if (!rendered.hasCell) {
    throw new Error("missing .rt-cell render target");
  }
  if (rendered.bodyTextLength === 0 || rendered.htmlLength === 0) {
    throw new Error("frontend rendered a blank document body");
  }
  await assertFrontendInteractions(cdp);
  await cdp.close();
} finally {
  chromeProcess.kill("SIGTERM");
  for (const socket of sockets) socket.destroy();
  server.close();
  await waitForExit(chromeProcess, 2000);
  try {
    fs.rmSync(profile, { recursive: true, force: true });
  } catch {
    // Chrome can briefly hold profile files after exit on some systems.
  }
}
}

function contentType(file) {
  switch (path.extname(file)) {
    case ".html": return "text/html; charset=utf-8";
    case ".js": return "text/javascript; charset=utf-8";
    case ".css": return "text/css; charset=utf-8";
    case ".json": return "application/json; charset=utf-8";
    case ".svg": return "image/svg+xml";
    default: return "application/octet-stream";
  }
}

function findChrome() {
  const candidates = [
    process.env.CHROME_BIN,
    "chromium",
    "chromium-browser",
    "google-chrome",
    "google-chrome-stable",
    "chrome",
  ].filter(Boolean);
  for (const candidate of candidates) {
    const result = childProcess.spawnSync("bash", ["-lc", `command -v ${shellQuote(candidate)}`], { encoding: "utf8" });
    if (result.status === 0 && result.stdout.trim()) return result.stdout.trim();
  }
  throw new Error("Chromium/Chrome is required for the frontend render smoke");
}

function shellQuote(value) {
  return `'${String(value).replaceAll("'", "'\\''")}'`;
}

async function listenPort() {
  const probe = net.createServer();
  await new Promise((resolve) => probe.listen(0, "127.0.0.1", resolve));
  const { port } = probe.address();
  await new Promise((resolve) => probe.close(resolve));
  return port;
}

async function waitForRender(cdp, failures) {
  const expression = `(() => {
    const brand = document.querySelector(".rt-brand")?.textContent || "";
    const hasCell = Boolean(document.querySelector(".rt-cell"));
    const bodyTextLength = (document.body?.innerText || "").trim().length;
    const htmlLength = document.body?.innerHTML.length || 0;
    return { brand, hasCell, bodyTextLength, htmlLength };
  })()`;
  let last = null;
  const started = Date.now();
  while (Date.now() - started < 5000) {
    const response = await cdp.send("Runtime.evaluate", {
      expression,
      awaitPromise: true,
      returnByValue: true,
    });
    last = response.result.value;
    if (last?.brand && last?.hasCell && last?.bodyTextLength > 0 && failures.length === 0) {
      return last;
    }
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  return last || {};
}

async function assertFrontendInteractions(cdp) {
  await evaluateOrThrow(cdp, `(() => {
    const graphicSelector = "path,line,polyline,rect,circle";
    const buttons = [...document.querySelectorAll(".rt-icon-button")];
    if (buttons.length === 0) throw new Error("missing .rt-icon-button elements");
    const failures = [];

    function isVisibleGraphic(node) {
      const box = node.getBBox();
      const style = getComputedStyle(node);
      const svgStyle = getComputedStyle(node.closest("svg"));
      const stroke = style.stroke || svgStyle.stroke;
      const fill = style.fill || svgStyle.fill;
      const tag = node.tagName.toLowerCase();
      const hasStroke = stroke !== "none" && stroke !== "rgba(0, 0, 0, 0)";
      const hasFill = fill !== "none" && fill !== "rgba(0, 0, 0, 0)";
      const canDraw = tag === "line" || tag === "polyline" ? hasStroke : hasStroke || hasFill;
      return (box.width > 0 || box.height > 0)
        && style.display !== "none"
        && style.visibility !== "hidden"
        && style.opacity !== "0"
        && svgStyle.display !== "none"
        && svgStyle.visibility !== "hidden"
        && svgStyle.opacity !== "0"
        && canDraw;
    }

    for (const button of buttons) {
      const svg = button.querySelector("svg");
      const svgBox = svg?.getBoundingClientRect();
      const visibleGraphic = [...(svg?.querySelectorAll(graphicSelector) || [])].some(isVisibleGraphic);
      if (!svg || !svgBox || svgBox.width === 0 || svgBox.height === 0 || !visibleGraphic) {
        failures.push(button.getAttribute("aria-label") || button.title || button.className || "unknown icon button");
      }
    }
    if (failures.length > 0) {
      throw new Error("icon buttons without visible SVG glyphs: " + failures.join(", "));
    }

    for (const selector of [".rt-cell-grip", ".rt-cell-select"]) {
      const button = document.querySelector(selector);
      const glyph = button?.querySelector(graphicSelector);
      if (!button || !glyph || !isVisibleGraphic(glyph)) {
        throw new Error(selector + " does not contain a visible icon glyph");
      }
    }
  })()`);

  await evaluateOrThrow(cdp, `(() => {
    const cell = document.querySelector(".rt-cell.is-stopped.has-text-idle.is-valid");
    const button = cell?.querySelector('.rt-cell-actions button[title="Launch cell"]:not(:disabled)');
    if (!cell || !button) throw new Error("missing enabled launchable stopped cell action");
    button.click();
  })()`);
  await waitForCondition(cdp, `(() => Boolean(document.querySelector(".rt-cell.is-active-playing .rt-cell-actions button[title='Stop cell']:not(:disabled)")))()`, 2000, "launchable cell did not become active with enabled stop action");
  await evaluateOrThrow(cdp, `(() => {
    const button = document.querySelector(".rt-cell.is-active-playing .rt-cell-actions button[title='Stop cell']:not(:disabled)");
    if (!button) throw new Error("missing enabled stop action for active cell");
    button.click();
  })()`);
  await waitForCondition(cdp, `(() => Boolean(document.querySelector(".rt-cell.is-stopped .rt-cell-actions button[title='Launch cell']:not(:disabled)")))()`, 2000, "second launch click did not stop/un-arm the active cell");

  await evaluateOrThrow(cdp, `(() => {
    const button = document.querySelector(".rt-danger[title^='Delete ']");
    if (!button) throw new Error("missing delete danger button");
    const before = button.title;
    button.click();
    return before;
  })()`);
  await waitForCondition(cdp, `(() => Boolean(document.querySelector(".rt-danger[title^='Confirm delete ']")))()`, 2000, "delete danger button did not arm for confirmation");
}

async function evaluateOrThrow(cdp, expression) {
  const response = await cdp.send("Runtime.evaluate", {
    expression,
    awaitPromise: true,
    returnByValue: true,
  });
  if (response.exceptionDetails) {
    const exception = response.exceptionDetails.exception;
    throw new Error(exception?.description || response.exceptionDetails.text || "browser evaluation failed");
  }
  return response.result?.value;
}

async function waitForCondition(cdp, expression, timeoutMs, message) {
  const started = Date.now();
  while (Date.now() - started < timeoutMs) {
    if (await evaluateOrThrow(cdp, expression)) return;
    await new Promise((resolve) => setTimeout(resolve, 50));
  }
  throw new Error(message);
}

async function waitUntil(predicate, timeoutMs, message) {
  const started = Date.now();
  while (Date.now() - started < timeoutMs) {
    const value = predicate();
    if (value) return value;
    await new Promise((resolve) => setTimeout(resolve, 50));
  }
  throw new Error(message);
}

async function waitForExit(process, timeoutMs) {
  if (process.exitCode !== null || process.signalCode !== null) return;
  await Promise.race([
    new Promise((resolve) => process.once("exit", resolve)),
    new Promise((resolve) => setTimeout(resolve, timeoutMs)),
  ]);
}

function isIgnorable(text) {
  return /favicon/i.test(text) && /404|not found|failed to load/i.test(text);
}

async function connectCdp(browserUrl) {
  const target = await jsonGet(new URL("/json/new", browserUrl));
  const socket = new WebSocket(target.webSocketDebuggerUrl);
  const callbacks = new Map();
  const handlers = new Map();
  let nextId = 1;

  socket.addEventListener("message", (event) => {
    const message = JSON.parse(event.data);
    if (message.id) {
      const callback = callbacks.get(message.id);
      callbacks.delete(message.id);
      if (!callback) return;
      if (message.error) callback.reject(new Error(message.error.message));
      else callback.resolve(message.result || {});
      return;
    }
    for (const handler of handlers.get(message.method) || []) handler(message.params || {});
  });

  await new Promise((resolve, reject) => {
    socket.addEventListener("open", resolve, { once: true });
    socket.addEventListener("error", reject, { once: true });
  });

  return {
    send(method, params = {}) {
      const id = nextId++;
      socket.send(JSON.stringify({ id, method, params }));
      return new Promise((resolve, reject) => callbacks.set(id, { resolve, reject }));
    },
    on(method, handler) {
      handlers.set(method, [...(handlers.get(method) || []), handler]);
    },
    once(method, timeoutMs) {
      return new Promise((resolve, reject) => {
        const timeout = setTimeout(() => reject(new Error(`timed out waiting for ${method}`)), timeoutMs);
        this.on(method, (params) => {
          clearTimeout(timeout);
          resolve(params);
        });
      });
    },
    close() {
      socket.close();
    },
  };
}

function jsonGet(url) {
  return new Promise((resolve, reject) => {
    const req = http.request({
      hostname: url.hostname,
      port: url.port,
      path: `${url.pathname}${url.search}`,
      method: "PUT",
    }, (res) => {
      let body = "";
      res.setEncoding("utf8");
      res.on("data", (chunk) => body += chunk);
      res.on("end", () => {
        if (res.statusCode < 200 || res.statusCode >= 300) {
          reject(new Error(`DevTools HTTP ${res.statusCode}: ${body}`));
          return;
        }
        resolve(JSON.parse(body));
      });
    });
    req.on("error", reject);
    req.end();
  });
}
NODE
