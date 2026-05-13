const GREEN = "\x1b[32m";
const RED = "\x1b[31m";
const YELLOW = "\x1b[33m";
const DIM = "\x1b[2m";
const RESET = "\x1b[0m";

const useColor = process.stdout.isTTY && !process.env.NO_COLOR;
const wrap = (color, s) => (useColor ? `${color}${s}${RESET}` : s);

export const log = {
  ok:    (msg) => console.log(`  ${wrap(GREEN, "✓")} ${msg}`),
  fail:  (msg) => console.log(`  ${wrap(RED, "✗")} ${msg}`),
  warn:  (msg) => console.log(`  ${wrap(YELLOW, "!")} ${msg}`),
  info:  (msg) => console.log(`  ${wrap(DIM, "·")} ${msg}`),
  plain: (msg) => console.log(msg),
};
