const noopSocket = {
  send() {},
  close() {}
};

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

const websocketUrl = () => {
  const location = globalThis.location;
  if (!location) {
    return "/ws";
  }

  const protocol = location.protocol === "https:" ? "wss:" : "ws:";
  return `${protocol}//${location.host}/ws`;
};

export const connectImpl = (handlers) => () => {
  try {
    const socket = new WebSocket(websocketUrl());

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
