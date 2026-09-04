import { DEFAULTS, FONTS, applyComposerState } from "./layout.js";

const textEl = document.querySelector("#text");
const fontEl = document.querySelector("#font");
const sizeEl = document.querySelector("#size");
const sizeValue = document.querySelector("#size-value");
const invertEls = document.querySelectorAll("input[name='invert']");
const labelEl = document.querySelector("#label");
const wordsEl = document.querySelector("#label-words");
const pageStyleEl = document.querySelector("#print-page");
const printBtn = document.querySelector("#print");

function populateFonts() {
  for (const family of FONTS) {
    const opt = document.createElement("option");
    opt.value = family;
    opt.textContent = family;
    if (family === DEFAULTS.fontFamily) opt.selected = true;
    fontEl.append(opt);
  }
}

function readState() {
  const invert = document.querySelector("input[name='invert']:checked")?.value === "1";
  return {
    ...DEFAULTS,
    text: textEl.value,
    fontFamily: fontEl.value,
    fontSizePt: Number(sizeEl.value),
    invert,
  };
}

function render() {
  const layout = applyComposerState(readState());
  labelEl.style.width = layout.style.width;
  labelEl.style.height = layout.style.height;
  labelEl.style.background = layout.style.background;
  labelEl.style.color = layout.style.color;
  wordsEl.style.fontFamily = layout.style.fontFamily;
  wordsEl.style.fontSize = layout.style.fontSize;
  wordsEl.style.color = layout.style.color;
  wordsEl.style.transform = layout.style.transform;
  wordsEl.textContent = layout.lines.join("\n");
  pageStyleEl.textContent = layout.page;
  sizeValue.textContent = `${layout.fontSizePt} pt`;
}

populateFonts();
textEl.value = DEFAULTS.text;
sizeEl.value = String(DEFAULTS.fontSizePt);
document.querySelector("input[name='invert'][value='0']").checked = true;

for (const el of [textEl, fontEl, sizeEl, ...invertEls]) {
  el.addEventListener("input", render);
  el.addEventListener("change", render);
}

printBtn.addEventListener("click", () => {
  render();
  window.print();
});

render();
