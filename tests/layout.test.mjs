import { test } from "node:test";
import assert from "node:assert/strict";
import {
  DEFAULTS,
  FONTS,
  applyComposerState,
  invertColors,
  splitNameLines,
  pageCss,
  innerTransform,
} from "../js/layout.js";

test("defaults are 100 mm × 150 mm with 90° word orientation", () => {
  const layout = applyComposerState();
  assert.equal(layout.widthMm, 100);
  assert.equal(layout.heightMm, 150);
  assert.equal(layout.rotateDeg, 90);
  assert.equal(layout.style.width, "100mm");
  assert.equal(layout.style.height, "150mm");
  assert.equal(layout.style.transform, innerTransform(90));
  assert.match(layout.style.transform, /90/);
  assert.equal(DEFAULTS.widthMm, layout.widthMm);
  assert.equal(DEFAULTS.heightMm, layout.heightMm);
});

test("invert maps to black-on-white vs white-on-black", () => {
  const normal = applyComposerState({ invert: false });
  const flipped = applyComposerState({ invert: true });
  const expectedNormal = invertColors(false);
  const expectedFlip = invertColors(true);

  assert.equal(normal.colors.color, expectedNormal.color);
  assert.equal(normal.colors.background, expectedNormal.background);
  assert.equal(normal.style.color, expectedNormal.color);
  assert.equal(normal.style.background, expectedNormal.background);

  assert.equal(flipped.colors.color, expectedFlip.color);
  assert.equal(flipped.colors.background, expectedFlip.background);
  assert.equal(flipped.style.color, expectedFlip.color);
  assert.equal(flipped.style.background, expectedFlip.background);

  assert.notEqual(normal.style.color, flipped.style.color);
  assert.notEqual(normal.style.background, flipped.style.background);
});

test("font family and letter size from controls flow into the preview", () => {
  const family = FONTS[2];
  const layout = applyComposerState({
    fontFamily: family,
    fontSizePt: 36,
    text: "Ana Perez",
  });
  assert.equal(layout.fontFamily, family);
  assert.equal(layout.style.fontFamily, family);
  assert.equal(layout.fontSizePt, 36);
  assert.equal(layout.style.fontSize, "36pt");
  assert.deepEqual(layout.lines, splitNameLines("Ana Perez"));
  assert.equal(layout.lines.length, 2);
});

test("Shift+Enter newlines keep vertical gaps between words", () => {
  const spaced = applyComposerState({ text: "Luciano\n\nOliva" });
  assert.deepEqual(spaced.lines, splitNameLines("Luciano\n\nOliva"));
  assert.equal(spaced.lines.length, 3);
  assert.equal(spaced.lines[0], "Luciano");
  assert.equal(spaced.lines[1], "");
  assert.equal(spaced.lines[2], "Oliva");

  const oneBreak = applyComposerState({ text: "Luciano\nOliva" });
  assert.equal(oneBreak.lines.length, 2);
  assert.equal(oneBreak.lines[0], "Luciano");
  assert.equal(oneBreak.lines[1], "Oliva");
});

test("print @page CSS matches stock size", () => {
  const layout = applyComposerState();
  const expected = pageCss(layout.widthMm, layout.heightMm);
  assert.equal(layout.page, expected);
  assert.match(layout.page, /100mm/);
  assert.match(layout.page, /150mm/);
});
