// Pure-logic tests for PmgModel.js. The module is a QML JS library (.pragma
// library) with top-level function declarations, so we evaluate it in a vm
// context and pull the functions off that context's global.
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import vm from "node:vm";

const here = dirname(fileURLToPath(import.meta.url));
const src = readFileSync(join(here, "..", "PmgModel.js"), "utf8").replace(/^\.pragma library\s*$/m, "");
const M = { Date };
vm.createContext(M);
vm.runInContext(src, M);

const T0 = Date.parse("2026-08-15T09:41:00Z");
const ago = (sec) => new Date(T0 - sec * 1000).toISOString();

test("parseLine handles valid, blank, and malformed input", () => {
  assert.equal(M.parseLine(""), null);
  assert.equal(M.parseLine("   "), null);
  assert.equal(M.parseLine("{not json"), null);
  const ev = M.parseLine('{"event_type":"install_allowed","package_name":"express"}');
  assert.equal(ev.event_type, "install_allowed");
  assert.equal(ev.package_name, "express");
});

test("parseLog skips blanks and bad lines", () => {
  const body = [
    '{"event_type":"install_allowed","package_name":"a"}',
    "",
    "garbage",
    '{"event_type":"malware_blocked","package_name":"b"}',
  ].join("\n");
  const events = M.parseLog(body);
  assert.equal(events.length, 2);
  assert.equal(events[0].package_name, "a");
  assert.equal(events[1].package_name, "b");
});

test("isDisplayable filters bookkeeping events", () => {
  assert.equal(M.isDisplayable({ event_type: "malware_blocked" }), true);
  assert.equal(M.isDisplayable({ event_type: "dependency_cooldown" }), true);
  assert.equal(M.isDisplayable({ event_type: "install_started" }), false);
  assert.equal(M.isDisplayable({ event_type: "session_complete" }), false);
  assert.equal(M.isDisplayable(null), false);
});

test("isBlock is true only for malware_blocked", () => {
  assert.equal(M.isBlock({ event_type: "malware_blocked" }), true);
  assert.equal(M.isBlock({ event_type: "malware_confirmed" }), false);
  assert.equal(M.isBlock({ event_type: "install_allowed" }), false);
});

test("todayCounts sums per-package verdicts without double counting", () => {
  const events = [
    { event_type: "install_allowed" },
    { event_type: "install_trusted_allowed" },
    { event_type: "dependency_cooldown" },
    { event_type: "malware_blocked" },
    { event_type: "session_complete", details: { allowed: 99 } }, // must be ignored
    { event_type: "install_started" }, // ignored
  ];
  const c = M.todayCounts(events);
  assert.equal(c.analyzed, 4);
  assert.equal(c.allowed, 2);
  assert.equal(c.held, 1);
  assert.equal(c.blocked, 1);
});

test("feedRows is newest-first, filtered, capped, and projected", () => {
  const events = [
    { event_type: "install_started", package_name: "x" },
    { event_type: "install_allowed", package_name: "express", version: "4.18.2", ecosystem: "npm", timestamp: ago(600) },
    { event_type: "dependency_cooldown", package_name: "left-pad", version: "1.3.1", ecosystem: "npm", timestamp: ago(120) },
    { event_type: "malware_blocked", package_name: "pino-sdk-v2", version: "2.0.1", ecosystem: "npm", timestamp: ago(30) },
  ];
  const rows = M.feedRows(events, 2, T0);
  assert.equal(rows.length, 2);
  assert.equal(rows[0].pkg, "pino-sdk-v2");
  assert.equal(rows[0].severity, "block");
  assert.equal(rows[0].ago, "now");
  assert.equal(rows[1].pkg, "left-pad");
  assert.equal(rows[1].severity, "hold");
});

test("newBlocksSince returns only newer blocks, newest first", () => {
  const events = [
    { event_type: "malware_blocked", package_name: "old", timestamp: ago(600) },
    { event_type: "install_allowed", package_name: "mid", timestamp: ago(120) },
    { event_type: "malware_blocked", package_name: "new", timestamp: ago(30) },
  ];
  const cutoff = T0 - 300 * 1000;
  const fresh = M.newBlocksSince(events, cutoff);
  assert.equal(fresh.length, 1);
  assert.equal(fresh[0].package_name, "new");
});

test("relativeTime buckets", () => {
  assert.equal(M.relativeTime(T0, T0), "now");
  assert.equal(M.relativeTime(T0 - 90 * 1000, T0), "1m");
  assert.equal(M.relativeTime(T0 - 2 * 3600 * 1000, T0), "2h");
  assert.equal(M.relativeTime(T0 - 3 * 86400 * 1000, T0), "3d");
  assert.equal(M.relativeTime(0, T0), "");
});

test("dailyLogName matches PMG's YYYYMMDD-pmg.log", () => {
  assert.equal(M.dailyLogName(new Date("2026-08-15T09:41:00Z")), "20260815-pmg.log");
  assert.equal(M.dailyLogName(new Date("2026-01-05T00:00:00Z")), "20260105-pmg.log");
});

test("healthSeverity maps info health to widget intent", () => {
  assert.equal(M.healthSeverity("protected"), "ok");
  assert.equal(M.healthSeverity("degraded"), "warn");
  assert.equal(M.healthSeverity("unprotected"), "bad");
  assert.equal(M.healthSeverity(undefined), "bad");
});
