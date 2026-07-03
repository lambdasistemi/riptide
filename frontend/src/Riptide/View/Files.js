import { Just, Nothing } from "../Data.Maybe/index.js";

const nothing = Nothing.value;

const maybeToJson = (value) => {
  if (value instanceof Just) return value.value0;
  if (value instanceof Nothing) return null;
  return value == null ? null : value;
};

const maybeFromJson = (value, valid) =>
  value == null ? nothing : valid(value) ? Just.create(value) : null;

const isString = (value) => typeof value === "string";
const isNumber = (value) => Number.isInteger(value);
const isBoolean = (value) => typeof value === "boolean";
const isObject = (value) => value != null && typeof value === "object" && !Array.isArray(value);

const cleanName = (name, fallback) => {
  const trimmed = String(name || fallback).trim();
  return (trimmed || fallback).replace(/[^a-z0-9._-]+/gi, "-").replace(/^-+|-+$/g, "") || fallback;
};

const downloadJson = (filename, value) => {
  const blob = new Blob([JSON.stringify(value, null, 2) + "\n"], { type: "application/json" });
  const link = document.createElement("a");
  const url = URL.createObjectURL(blob);
  link.href = url;
  link.download = cleanName(filename, "riptide-export.json");
  link.style.display = "none";
  document.body.appendChild(link);
  link.click();
  link.remove();
  setTimeout(() => URL.revokeObjectURL(url), 0);
};

const songToJson = (song) => ({
  riptideSong: 1,
  name: song.name,
  tracks: song.tracks.map((track) => ({
    name: track.name,
    hue: maybeToJson(track.hue),
    vol: maybeToJson(track.vol),
    flt: maybeToJson(track.flt),
    dly: maybeToJson(track.dly),
    active: maybeToJson(track.active),
    selected: maybeToJson(track.selected),
    score: track.score,
    cells: track.cells.map((cell) => ({ id: cell.id, code: cell.code })),
  })),
});

const toolboxToJson = (toolbox) => ({
  riptideToolbox: 1,
  name: toolbox.name,
  blocks: toolbox.blocks.map((block) => ({ name: block.name, code: block.code })),
});

export const downloadSongJson = (filename) => (song) => () => {
  downloadJson(filename, songToJson(song));
};

export const downloadToolboxJson = (filename) => (toolbox) => () => {
  downloadJson(filename, toolboxToJson(toolbox));
};

const readMaybe = (value, valid) => {
  const maybe = maybeFromJson(value, valid);
  if (maybe == null) throw new Error("invalid optional field");
  return maybe;
};

const parseCell = (cell) => {
  if (!isObject(cell) || !isString(cell.id) || !isString(cell.code)) throw new Error("invalid cell");
  return { id: cell.id, code: cell.code };
};

const parseTrack = (track) => {
  if (!isObject(track) || !isString(track.name) || !Array.isArray(track.score) || !Array.isArray(track.cells)) {
    throw new Error("invalid track");
  }
  if (!track.score.every(isBoolean)) throw new Error("invalid score");
  return {
    name: track.name,
    hue: readMaybe(track.hue, isNumber),
    vol: readMaybe(track.vol, isNumber),
    flt: readMaybe(track.flt, isNumber),
    dly: readMaybe(track.dly, isNumber),
    active: readMaybe(track.active, isString),
    selected: readMaybe(track.selected, isString),
    score: track.score,
    cells: track.cells.map(parseCell),
  };
};

const parseBlock = (block) => {
  if (!isObject(block) || !isString(block.name) || !isString(block.code)) throw new Error("invalid block");
  return { name: block.name, code: block.code };
};

export const parseSongFile = (text) => {
  try {
    const parsed = JSON.parse(text);
    if (!isObject(parsed) || parsed.riptideSong !== 1 || !isString(parsed.name) || !Array.isArray(parsed.tracks)) {
      throw new Error("invalid song");
    }
    return [{ riptideSong: 1, name: parsed.name, tracks: parsed.tracks.map(parseTrack) }];
  } catch (_) {
    return [];
  }
};

export const parseToolboxFile = (text) => {
  try {
    const parsed = JSON.parse(text);
    if (!isObject(parsed) || parsed.riptideToolbox !== 1 || !isString(parsed.name) || !Array.isArray(parsed.blocks)) {
      throw new Error("invalid toolbox");
    }
    return [{ riptideToolbox: 1, name: parsed.name, blocks: parsed.blocks.map(parseBlock) }];
  } catch (_) {
    return [];
  }
};

export const pickTextFile = (emit) => () => {
  const input = document.createElement("input");
  let cancelled = false;
  input.type = "file";
  input.accept = "application/json,.json";
  input.style.display = "none";

  const cleanup = () => {
    cancelled = true;
    input.remove();
  };

  input.addEventListener("change", () => {
    const file = input.files && input.files[0];
    if (!file) {
      if (!cancelled) emit({ ok: false, value: "No file selected" })();
      cleanup();
      return;
    }

    file.text().then(
      (text) => {
        if (!cancelled) emit({ ok: true, value: text })();
        cleanup();
      },
      () => {
        if (!cancelled) emit({ ok: false, value: "Could not read selected file" })();
        cleanup();
      }
    );
  });

  input.addEventListener("cancel", () => {
    if (!cancelled) emit({ ok: false, value: "No file selected" })();
    cleanup();
  });

  document.body.appendChild(input);
  input.click();

  return cleanup;
};

export const timeout = (ms) => (action) => (emit) => () => {
  const id = setTimeout(() => emit(action)(), ms);
  return () => clearTimeout(id);
};
