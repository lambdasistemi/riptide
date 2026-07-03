export const animationFrames = (emit) => () => {
  let frame = 0;
  let last = null;
  let cancelled = false;

  const request =
    globalThis.requestAnimationFrame ||
    ((callback) => globalThis.setTimeout(() => callback(globalThis.performance.now()), 16));
  const cancel =
    globalThis.cancelAnimationFrame ||
    globalThis.clearTimeout;

  const loop = (now) => {
    if (cancelled) return;
    const dt = last == null ? 0 : (now - last) / 1000;
    last = now;
    emit(dt)();
    frame = request(loop);
  };

  frame = request(loop);

  return () => {
    cancelled = true;
    cancel(frame);
  };
};
