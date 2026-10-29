"use strict";
const crypto = require("node:crypto");
class InputError extends Error {}
function text(value, label, max, optional = false) {
  if (optional && (value === undefined || value === null)) return "";
  if (typeof value !== "string" || value.trim().length > max || (!optional && !value.trim())) {
    throw new InputError(`${label} must be ${optional ? "up to" : "between 1 and"} ${max} characters.`);
  }
  return value.trim();
}
function date(value) {
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(value) ||
      !Number.isFinite(Date.parse(value)) || new Date(value).toISOString().slice(0, 10) !== value) {
    throw new InputError("Choose a valid calendar date.");
  }
  return value;
}
function id(value) {
  if (typeof value !== "string" || !/^[A-Za-z0-9_-]{8,80}$/.test(value)) throw new InputError("Invalid request ID.");
  return value;
}
function drawing(value) {
  if (!Array.isArray(value) || !value.length || value.length > 8000) throw new InputError("Drawing is empty or too large.");
  for (const p of value) {
    if (!Array.isArray(p) || p.length !== 3 || !p.every(Number.isFinite) ||
        !((p[0] === -1 && p[1] === -1) || (p[0] >= 0 && p[0] <= 1 && p[1] >= 0 && p[1] <= 1)) ||
        !Number.isInteger(p[2]) || p[2] < 0 || p[2] > 4294967295) throw new InputError("Invalid drawing points.");
  }
  // Firestore cannot store arrays nested inside arrays.
  return value.map(([x, y, color]) => ({ x, y, color }));
}
function inviteCode() { return crypto.randomBytes(6).toString("hex").toUpperCase(); }
function hash(value) { return crypto.createHash("sha256").update(value).digest("hex"); }
module.exports = { InputError, text, date, id, drawing, inviteCode, hash };
