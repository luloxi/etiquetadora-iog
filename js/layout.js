/** Preview/print layout for Unnion LP4206D 10×15 cm labels. Used by the UI and tests. */

export const DEFAULTS = {
  widthMm: 100,
  heightMm: 150,
  rotateDeg: 90,
  fontSizePt: 28,
  fontFamily: "Arial",
  invert: false,
  text: "Luciano Oliva",
};

export const FONTS = [
  "Arial",
  "Georgia",
  "Times New Roman",
  "Courier New",
  "Verdana",
  "Trebuchet MS",
  "Impact",
];

export function splitNameLines(text) {
  const raw = String(text ?? "").replace(/\r\n/g, "\n");
  // Shift+Enter inserts \n in the textarea; keep those breaks, including
  // blank lines so extra Enter adds vertical space between words.
  if (raw.includes("\n")) {
    const lines = raw.split("\n").map((line) => line.replace(/[ \t]+/g, " ").trimEnd());
    if (lines.every((line) => line.trim() === "")) return [""];
    return lines;
  }
  const parts = raw.trim().split(/\s+/).filter(Boolean);
  if (parts.length >= 2) {
    return [parts.slice(0, -1).join(" "), parts[parts.length - 1]];
  }
  if (parts.length === 1) return [parts[0]];
  return [""];
}

export function invertColors(invert) {
  if (invert) {
    return { color: "#ffffff", background: "#000000" };
  }
  return { color: "#000000", background: "#ffffff" };
}

export function pageCss(widthMm, heightMm) {
  return `@page { size: ${widthMm}mm ${heightMm}mm; margin: 0; }`;
}

export function innerTransform(rotateDeg) {
  return `rotate(${rotateDeg}deg)`;
}

/**
 * Full composer snapshot: size, 90° word orientation, invert, font, size, lines.
 */
export function applyComposerState(input = {}) {
  const state = { ...DEFAULTS, ...input };
  const colors = invertColors(Boolean(state.invert));
  const lines = splitNameLines(state.text);
  return {
    widthMm: state.widthMm,
    heightMm: state.heightMm,
    rotateDeg: state.rotateDeg,
    fontSizePt: state.fontSizePt,
    fontFamily: state.fontFamily,
    invert: Boolean(state.invert),
    lines,
    colors,
    style: {
      width: `${state.widthMm}mm`,
      height: `${state.heightMm}mm`,
      background: colors.background,
      color: colors.color,
      fontFamily: state.fontFamily,
      fontSize: `${state.fontSizePt}pt`,
      transform: innerTransform(state.rotateDeg),
    },
    page: pageCss(state.widthMm, state.heightMm),
  };
}
