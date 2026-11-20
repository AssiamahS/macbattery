// macbattery: Mac posts its battery state here, the iPhone widget reads it back.
// POST /battery[/<device>]  (header X-Battery-Secret must match the REPORT_SECRET secret)
// GET  /battery[/<device>]  -> that device's latest JSON, plus server receivedAt and ageSeconds
// GET  /batteries           -> { devices: { mac, watch, iphone } } for whichever have reported
// <device> is mac (default), watch or iphone.
// GET  /         -> live ring page for the iPhone Home Screen, GET /icon.png its touch icon

import { ICON_B64 } from "./icon.js";
import { PAGE } from "./page.js";

const DEVICES = ["mac", "watch", "iphone"];
// The Mac keeps the original key so nothing had to migrate.
const keyFor = (device) => (device === "mac" ? "latest" : `dev:${device}`);
// An unchanged report inside this window is not rewritten: keeps KV under the free 1,000 writes/day
// with three devices reporting. Must stay well under the widget's 10 minute stale threshold.
const MIN_REWRITE_MS = 5 * 60 * 1000;
const JSON_HEADERS = { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" };

const json = (body, status = 200) => new Response(JSON.stringify(body), { status, headers: JSON_HEADERS });

function timingSafeEqual(a, b) {
  const enc = new TextEncoder();
  const x = enc.encode(a);
  const y = enc.encode(b);
  if (x.length !== y.length) return false;
  let diff = 0;
  for (let i = 0; i < x.length; i++) diff |= x[i] ^ y[i];
  return diff === 0;
}

const withAge = (stored) => ({
  ...stored,
  ageSeconds: Math.max(0, Math.round((Date.now() - Date.parse(stored.receivedAt)) / 1000)),
});

const unchanged = (a, b) =>
  a.percent === b.percent && a.charging === b.charging && a.onAC === b.onAC && a.state === b.state;

function sanitize(input) {
  const percent = Number(input.percent);
  if (!Number.isFinite(percent) || percent < 0 || percent > 100) return null;
  const minutes = input.minutesRemaining == null ? null : Number(input.minutesRemaining);
  return {
    percent: Math.round(percent),
    charging: Boolean(input.charging),
    onAC: Boolean(input.onAC),
    state: String(input.state ?? "").slice(0, 32),
    minutesRemaining: Number.isFinite(minutes) && minutes >= 0 ? Math.round(minutes) : null,
    device: String(input.device ?? "MacBook").slice(0, 64),
    reportedAt: String(input.reportedAt ?? "").slice(0, 40),
  };
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (request.method === "GET" && url.pathname === "/") {
      return new Response(PAGE, { headers: { "content-type": "text/html; charset=utf-8", "cache-control": "no-cache" } });
    }
    if (request.method === "GET" && (url.pathname === "/icon.png" || url.pathname.startsWith("/apple-touch-icon"))) {
      const bytes = Uint8Array.from(atob(ICON_B64), (c) => c.charCodeAt(0));
      return new Response(bytes, { headers: { "content-type": "image/png", "cache-control": "public, max-age=86400" } });
    }
    if (request.method === "GET" && url.pathname === "/batteries") {
      const stored = await Promise.all(DEVICES.map((d) => env.BATTERY.get(keyFor(d), "json")));
      const devices = {};
      DEVICES.forEach((d, i) => {
        if (stored[i]) devices[d] = withAge(stored[i]);
      });
      return json({ devices });
    }

    const match = url.pathname.match(/^\/battery(?:\/([a-z]+))?$/);
    const device = match ? (match[1] ?? "mac") : null;
    if (!device || !DEVICES.includes(device)) return json({ error: "not found" }, 404);
    const KEY = keyFor(device);

    if (request.method === "GET") {
      const stored = await env.BATTERY.get(KEY, "json");
      if (!stored) return json({ error: "no data yet" }, 404);
      return json(withAge(stored));
    }

    if (request.method === "POST") {
      const secret = request.headers.get("x-battery-secret") ?? "";
      if (!env.REPORT_SECRET || !timingSafeEqual(secret, env.REPORT_SECRET)) {
        return json({ error: "unauthorized" }, 401);
      }
      let body;
      try {
        body = await request.json();
      } catch {
        return json({ error: "invalid json" }, 400);
      }
      const clean = sanitize(body ?? {});
      if (!clean) return json({ error: "invalid percent" }, 400);
      const previous = await env.BATTERY.get(KEY, "json");
      if (previous && unchanged(previous, clean) && Date.now() - Date.parse(previous.receivedAt) < MIN_REWRITE_MS) {
        return json({ ok: true, skipped: true, ...previous });
      }
      const record = { ...clean, receivedAt: new Date().toISOString() };
      await env.BATTERY.put(KEY, JSON.stringify(record));
      return json({ ok: true, ...record });
    }

    return json({ error: "method not allowed" }, 405);
  },
};
