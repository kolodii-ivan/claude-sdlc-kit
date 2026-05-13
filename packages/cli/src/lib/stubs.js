export const STUB_PATHS = [
  ".github/workflows/claude-brainstorm.yml",
  ".github/workflows/claude-implement.yml",
  ".github/workflows/claude-iterate.yml",
];

const KIT_REPO = "kolodii-ivan/claude-sdlc-kit";
const PIN_RE = new RegExp(
  `${KIT_REPO.replace(/[\/\.\-]/g, "\\$&")}/[^@\\s]+@([\\w\\.\\-]+)`
);

export function applyPin(template, pin) {
  return template.replaceAll("__PIN__", pin);
}

export function extractPin(stubContent) {
  const m = stubContent.match(PIN_RE);
  return m ? m[1] : null;
}
