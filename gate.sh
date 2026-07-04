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
      const buttonBox = button.getBoundingClientRect();
      const style = getComputedStyle(button);
      const visibleGraphic = [...(svg?.querySelectorAll(graphicSelector) || [])].some(isVisibleGraphic);
      if (!svg || !svgBox || svgBox.width === 0 || svgBox.height === 0 || !visibleGraphic) {
        failures.push(button.getAttribute("aria-label") || button.title || button.className || "unknown icon button");
        continue;
      }
      const dx = Math.abs((svgBox.left + svgBox.width / 2) - (buttonBox.left + buttonBox.width / 2));
      const dy = Math.abs((svgBox.top + svgBox.height / 2) - (buttonBox.top + buttonBox.height / 2));
      if (!["flex", "inline-flex"].includes(style.display) || dx > 1 || dy > 1) {
        failures.push((button.getAttribute("aria-label") || button.title || button.className || "unknown icon button") + " not centered");
      }
    }
    if (failures.length > 0) {
      throw new Error("icon button glyph failures: " + failures.join(", "));
    }

    for (const selector of [".rt-cell-grip", ".rt-cell-add"]) {
      const button = document.querySelector(selector);
      const svg = button?.querySelector("svg");
      const glyph = button?.querySelector(graphicSelector);
      if (!button || !glyph || !isVisibleGraphic(glyph)) {
        throw new Error(selector + " does not contain a visible icon glyph");
      }
      const style = getComputedStyle(button);
      const buttonBox = button.getBoundingClientRect();
      const svgBox = svg.getBoundingClientRect();
      const dx = Math.abs((svgBox.left + svgBox.width / 2) - (buttonBox.left + buttonBox.width / 2));
      const dy = Math.abs((svgBox.top + svgBox.height / 2) - (buttonBox.top + buttonBox.height / 2));
      if (!["flex", "inline-flex"].includes(style.display) || dx > 1 || dy > 1) {
        throw new Error(selector + " icon glyph is not centered");
      }
    }
  })()`);

  await evaluateOrThrow(cdp, `(() => {
    const failures = [];
    const tracks = [...document.querySelectorAll(".rt-track")];
    if (tracks.length === 0) failures.push("missing tracks");

    for (const track of tracks) {
      const radios = [...track.querySelectorAll(".rt-cell-head input.rt-cell-select[type='radio']")];
      const cells = [...track.querySelectorAll(".rt-cell")];
      if (radios.length !== cells.length) {
        failures.push("track has " + radios.length + " radio selectors for " + cells.length + " cells");
        continue;
      }
      if (new Set(radios.map((radio) => radio.name)).size !== 1) {
        failures.push("track radios are not one named group");
      }
      if (radios.filter((radio) => radio.checked).length !== 1) {
        failures.push("track radio group does not have exactly one selected cell");
      }
      for (const radio of radios) {
        const box = radio.getBoundingClientRect();
        const style = getComputedStyle(radio);
        if (box.width < 12 || box.height < 12 || style.display === "none" || style.visibility === "hidden" || style.opacity === "0") {
          failures.push("cell selector radio is not visibly native-sized");
        }
        const headBox = radio.closest(".rt-cell-head")?.getBoundingClientRect();
        if (!headBox || Math.abs((box.top + box.height / 2) - (headBox.top + headBox.height / 2)) > 1.5) {
          failures.push("cell selector radio is not vertically centered in the header");
        }
      }
    }

    const firstTrackRadios = [...document.querySelectorAll(".rt-track:first-of-type .rt-cell-head input.rt-cell-select[type='radio']")];
    if (firstTrackRadios.length >= 2) {
      const next = firstTrackRadios.find((radio) => !radio.checked) || firstTrackRadios[1];
      const groupName = next.name;
      next.click();
      const checked = [...document.querySelectorAll("input.rt-cell-select[type='radio'][name='" + CSS.escape(groupName) + "']")]
        .filter((radio) => radio.checked);
      if (checked.length !== 1 || checked[0] !== next) {
        failures.push("clicking a cell radio did not update the mutually exclusive checked state");
      }
    } else {
      failures.push("first track does not have enough radios for selection smoke");
    }

    const oldSelectButtons = [...document.querySelectorAll(".rt-cell-head button.rt-cell-select, .rt-cell-head button[title='Select cell'], .rt-cell-head button[aria-label='Select cell'], .rt-cell-head button[title='Selected cell'], .rt-cell-head button[aria-label='Selected cell']")];
    if (oldSelectButtons.length > 0) {
      failures.push("old eye select button still exists in cell headers");
    }

    for (const grip of document.querySelectorAll(".rt-drag-handle")) {
      const circles = [...grip.querySelectorAll("svg circle")];
      const lines = [...grip.querySelectorAll("svg line")];
      const linePoints = lines.map((line) => [line.getAttribute("x1"), line.getAttribute("y1"), line.getAttribute("x2"), line.getAttribute("y2")].join(","));
      const hasPauseLikeGlyph = linePoints.includes("9,5,9,19") && linePoints.includes("15,5,15,19");
      if (circles.length !== 6) {
        failures.push((grip.title || "drag handle") + " does not use a six-dot grip glyph");
      }
      if (hasPauseLikeGlyph) {
        failures.push((grip.title || "drag handle") + " still uses the pause-like two-line glyph");
      }
      const gripBox = grip.getBoundingClientRect();
      const svgBox = grip.querySelector("svg")?.getBoundingClientRect();
      if (!svgBox || Math.abs((svgBox.left + svgBox.width / 2) - (gripBox.left + gripBox.width / 2)) > 1 || Math.abs((svgBox.top + svgBox.height / 2) - (gripBox.top + gripBox.height / 2)) > 1) {
        failures.push((grip.title || "drag handle") + " glyph is not centered");
      }
    }

    if (failures.length > 0) {
      throw new Error("cell control cleanup failures: " + [...new Set(failures)].join("; "));
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
    const cell = [...document.querySelectorAll(".rt-cell")]
      .find((candidate) => (candidate.querySelector("textarea")?.value || "").includes('s "bd*2 sn:3"'));
    const button = cell?.querySelector(".rt-danger[title='Delete cell']");
    if (!button) throw new Error("missing delete danger button for target seed cell");
    const before = button.title;
    button.click();
    return before;
  })()`);
  await waitForCondition(cdp, `(() => Boolean(document.querySelector(".rt-danger[title='Confirm delete cell']")))()`, 2000, "delete danger button did not arm for confirmation");

  await evaluateOrThrow(cdp, `(() => {
    const confirmButton = document.querySelector(".rt-danger[title='Confirm delete cell']");
    if (!confirmButton) throw new Error("missing armed confirm delete cell button");
    const cancelButton = [...document.querySelectorAll("button")]
      .find((button) => button.title === "Cancel delete cell" || button.getAttribute("aria-label") === "Cancel delete cell");
    if (!cancelButton) throw new Error("missing explicit cancel delete cell button");
    cancelButton.click();
  })()`);
  await waitForCondition(cdp, `(() => {
    return Boolean(document.querySelector(".rt-danger[title='Delete cell']"))
      && !document.querySelector(".rt-danger[title^='Confirm delete ']")
      && [...document.querySelectorAll(".rt-cell")].some((cell) => (cell.querySelector("textarea")?.value || "").includes('s "bd*2 sn:3"'));
  })()`, 2000, "cancel delete did not clear confirmation while preserving the cell");

  await evaluateOrThrow(cdp, `(() => {
    const cell = [...document.querySelectorAll(".rt-cell")]
      .find((candidate) => (candidate.querySelector("textarea")?.value || "").includes('s "bd*2 sn:3"'));
    const button = cell?.querySelector(".rt-danger[title='Delete cell']");
    if (!button) throw new Error("missing target seed cell delete button after cancel");
    button.click();
  })()`);
  await waitForCondition(cdp, `(() => Boolean(document.querySelector(".rt-danger[title='Confirm delete cell']")))()`, 2000, "delete cell did not re-arm after cancel");
  await evaluateOrThrow(cdp, `(() => {
    const cell = [...document.querySelectorAll(".rt-cell")]
      .find((candidate) => (candidate.querySelector("textarea")?.value || "").includes('s "bd*2 sn:3"'));
    const button = cell?.querySelector(".rt-danger[title='Confirm delete cell']");
    if (!button) throw new Error("missing target seed cell confirm delete button");
    button.click();
  })()`);
  await waitForCondition(cdp, `(() => {
    return ![...document.querySelectorAll(".rt-cell")].some((cell) => (cell.querySelector("textarea")?.value || "").includes('s "bd*2 sn:3"'));
  })()`, 2000, "second confirm delete click did not remove the cell");
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
