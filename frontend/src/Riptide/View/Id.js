export const mintId = (prefix) => () =>
  prefix + Math.random().toString(36).slice(2, 8);
