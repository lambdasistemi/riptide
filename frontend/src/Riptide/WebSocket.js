const noopSocket = {
  send() {},
  close() {}
};

let fallbackBackendHost = "";
const backendHostKey = "riptide.backendHost";

const report = (handler, value) => {
  try {
    handler(value)();
  } catch (_) {}
};

const run = (effect) => {
  try {
    effect();
  } catch (_) {}
};

const normalizePath = (pathname) => {
  if (!pathname || pathname === "/") {
    return "/ws";
  }
  return pathname;
};

export const websocketUrlFromSetting = (page) => (rawSetting) => {
  const setting = String(rawSetting || "").trim();
  const pageProtocol = page && page.protocol === "https:" ? "wss:" : "ws:";
  const pageHost = page && page.host ? page.host : "";

  if (!setting) {
    return pageHost ? `${pageProtocol}//${pageHost}/ws` : "/ws";
  }

  if (setting.startsWith("ws://") || setting.startsWith("wss://")) {
    return setting;
  }

  if (setting.startsWith("http://") || setting.startsWith("https://")) {
    try {
      const url = new URL(setting);
      const protocol = url.protocol === "https:" ? "wss:" : "ws:";
      return `${protocol}//${url.host}${normalizePath(url.pathname)}${url.search}${url.hash}`;
    } catch (_) {
      return `${pageProtocol}//${setting}/ws`;
    }
  }

  return `${pageProtocol}//${setting}/ws`;
};

export const currentWebSocketUrl = (backendHost) => {
  const location = globalThis.location;
  if (!location) {
    return websocketUrlFromSetting({ protocol: "http:", host: "" })(backendHost);
  }

  return websocketUrlFromSetting({ protocol: location.protocol, host: location.host })(backendHost);
};

export const connectImpl = (url) => (handlers) => () => {
  try {
    const socket = new WebSocket(url);

    socket.onopen = () => run(handlers.onOpen);
    socket.onclose = () => run(handlers.onClose);
    socket.onerror = () => report(handlers.onError, "websocket error");
    socket.onmessage = (event) => {
      if (typeof event.data === "string") {
        report(handlers.onMessage, event.data);
      } else {
        report(handlers.onError, "websocket message was not text");
      }
    };

    return socket;
  } catch (error) {
    report(handlers.onError, error instanceof Error ? error.message : "websocket connection failed");
    return noopSocket;
  }
};

export const loadBackendHost = () => {
  try {
    const storage = globalThis.localStorage;
    if (!storage) {
      return fallbackBackendHost;
    }
    return storage.getItem(backendHostKey) || "";
  } catch (_) {
    return fallbackBackendHost;
  }
};

export const saveBackendHost = (value) => () => {
  const next = String(value || "");
  fallbackBackendHost = next;
  try {
    const storage = globalThis.localStorage;
    if (!storage) {
      return;
    }
    if (next) {
      storage.setItem(backendHostKey, next);
    } else {
      storage.removeItem(backendHostKey);
    }
  } catch (_) {}
};

export const sendImpl = (socket) => (message) => () => {
  try {
    if (socket && socket.readyState === WebSocket.OPEN) {
      socket.send(message);
    }
  } catch (_) {}
};

export const close = (socket) => () => {
  try {
    socket.close();
  } catch (_) {}
};
