// GET / : live battery ring for the iPhone Home Screen (Share > Add to Home Screen).
// Stopgap until the native widget build ships; polls /battery every 30 s.

export const PAGE = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-title" content="Mac Battery">
<meta name="apple-mobile-web-app-status-bar-style" content="default">
<meta name="theme-color" content="#e9e9eb" media="(prefers-color-scheme: light)">
<meta name="theme-color" content="#1c1c1e" media="(prefers-color-scheme: dark)">
<link rel="apple-touch-icon" href="/icon.png">
<title>Mac Battery</title>
<style>
  :root { --bg:#e9e9eb; --card:#c9c9cc; --fg:#fff; --sub:rgba(255,255,255,.75); --track:rgba(255,255,255,.28); --ring:#34c759; }
  @media (prefers-color-scheme: dark) {
    :root { --bg:#000; --card:#2c2c2e; --track:rgba(255,255,255,.16); }
  }
  * { box-sizing:border-box; -webkit-tap-highlight-color:transparent; }
  html,body { height:100%; margin:0; }
  body { background:var(--bg); display:flex; flex-direction:column; align-items:center; justify-content:center; gap:14px;
         font-family:-apple-system,system-ui,sans-serif; padding:16px; }
  .card { background:var(--card); color:var(--fg); border-radius:34px; width:min(100%,300px); aspect-ratio:1;
          display:flex; flex-direction:column; align-items:center; justify-content:center; gap:6px; }
  .ring { position:relative; width:58%; aspect-ratio:1; }
  .ring svg { width:100%; height:100%; display:block; }
  .track { fill:none; stroke:var(--track); stroke-width:9; }
  .level { fill:none; stroke:var(--ring); stroke-width:9; stroke-linecap:round; transform:rotate(-90deg); transform-origin:50% 50%;
           stroke-dasharray:289.03; stroke-dashoffset:289.03; transition:stroke-dashoffset .6s ease, stroke .3s; }
  .glyph { fill:none; stroke:var(--fg); stroke-width:3.2; stroke-linecap:round; stroke-linejoin:round; }
  .ring .bolt { position:absolute; top:-5%; left:50%; width:20%; height:auto; transform:translateX(-50%); display:none; }
  .charging .ring .bolt { display:block; }
  .pct { font-size:44px; font-weight:500; letter-spacing:-.5px; font-variant-numeric:tabular-nums; line-height:1.1; }
  .detail { font-size:15px; color:var(--sub); min-height:1.2em; }
  .name { font-size:14px; color:#3c3c43; }
  @media (prefers-color-scheme: dark) { .name { color:#ebebf5; opacity:.7; } }
  .stale { --ring:#8e8e93; }
  .low { --ring:#ff9f0a; }
  .critical { --ring:#ff3b30; }
</style>
</head>
<body>
<div class="card" id="card" role="img" aria-label="Mac battery">
  <div class="ring">
    <svg viewBox="0 0 110 110" aria-hidden="true">
      <circle class="track" cx="55" cy="55" r="46"/>
      <circle class="level" id="level" cx="55" cy="55" r="46"/>
      <rect class="glyph" x="39" y="42" width="32" height="21" rx="2.5"/>
      <path class="glyph" d="M33 69h44"/>
    </svg>
    <svg class="bolt" viewBox="0 0 24 24" aria-hidden="true">
      <circle cx="12" cy="12" r="12" fill="var(--card)"/>
      <path d="M13.6 3 6.5 13.2h4.6L10.2 21l7.3-10.4h-4.7z" fill="var(--ring)"/>
    </svg>
  </div>
  <div class="pct" id="pct">--%</div>
  <div class="detail" id="detail">Loading</div>
</div>
<div class="name" id="name">Mac Battery</div>
<script>
const CIRC = 289.03, STALE_AFTER = 600;
const $ = (id) => document.getElementById(id);

function detailText(s) {
  if (s.state === "charged") return "Charged";
  const m = s.minutesRemaining;
  if (!m) return s.charging ? "Charging" : (s.onAC ? "On power" : "On battery");
  const t = m >= 60 ? Math.floor(m / 60) + "h " + (m % 60) + "m" : m + "m";
  return s.charging ? t + " to full" : t + " left";
}

function ago(sec) {
  if (sec < 3600) return Math.round(sec / 60) + " min ago";
  if (sec < 86400) return Math.round(sec / 3600) + " hr ago";
  return Math.round(sec / 86400) + " d ago";
}

function render(s) {
  const stale = s.ageSeconds > STALE_AFTER;
  const card = $("card");
  card.className = "card" + (stale ? " stale" : "") + (s.charging && !stale ? " charging" : "")
    + (!s.charging && s.percent <= 10 ? " critical" : (!s.charging && s.percent <= 20 ? " low" : ""));
  $("level").style.strokeDashoffset = CIRC * (1 - Math.min(Math.max(s.percent, 0), 100) / 100);
  $("pct").textContent = s.percent + "%";
  $("detail").textContent = stale ? "Mac asleep · " + ago(s.ageSeconds) : detailText(s);
  $("name").textContent = s.device || "Mac Battery";
  card.setAttribute("aria-label", "Mac battery " + s.percent + " percent" + (stale ? ", last updated " + ago(s.ageSeconds) : ""));
}

async function load() {
  try {
    const r = await fetch("/battery", { cache: "no-store" });
    if (!r.ok) throw new Error(r.status);
    render(await r.json());
  } catch (e) {
    $("detail").textContent = "Can't reach server";
  }
}

load();
setInterval(load, 30000);
document.addEventListener("visibilitychange", () => { if (!document.hidden) load(); });
</script>
</body>
</html>
`;
