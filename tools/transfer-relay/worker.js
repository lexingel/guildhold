// Guildhold save transfer relay (Cloudflare Worker + KV).
// POST /send  body = exported save text -> {"code": "KX74QP"}; kept 15 minutes.
// GET  /take/<code>                     -> the save text, once (then deleted).
// Saves are a few dozen KB of game state.
// POST /daily/<day> body = {"guild": name, "score": n} -> {"rank": r, "top": [...]}
// GET  /daily/<day>                                     -> {"top": [...]}
// The daily board (0.70): a guild name and a score per entry, best kept,
// 50 per day, gone after 8 days. An entry is keyed by the install's random id
// (0.65; by the guild name for older builds). Nothing else about the player.
// POST /m body = {"id": install, ...} -> {"ok": true}
// Opt-in play milestones (0.65, Settings > Send feedback): the latest report
// per install, kept 90 days, read by the developer from KV (key "m:<id>").

const TTL = 900;                 // seconds a code stays valid
const MAX_BYTES = 512 * 1024;
const ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";   // no 0/O, 1/I
const ORIGINS = ["https://lexingel.github.io"];
const BOARD_TTL = 8 * 86400;
const BOARD_SIZE = 50;
const SCORE_MAX = 30000;   // 0.65: scores scale with the Hardship
const STATS_TTL = 90 * 86400;
const STATS_MAX = 4096;

function cors(req) {
  const o = req.headers.get("Origin") || "";
  return {
    "Access-Control-Allow-Origin": ORIGINS.includes(o) || o.startsWith("http://localhost") ? o : ORIGINS[0],
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    // Godot's web requests add their own headers (User-Agent and others), so
    // allow whatever the browser's preflight asks for.
    "Access-Control-Allow-Headers": req.headers.get("Access-Control-Request-Headers") || "Content-Type",
    "Access-Control-Max-Age": "86400",
    "Vary": "Origin",
  };
}

function reply(req, body, status = 200, type = "application/json") {
  return new Response(body, { status, headers: { "Content-Type": type, ...cors(req) } });
}

function newCode() {
  const b = crypto.getRandomValues(new Uint8Array(6));
  return Array.from(b, (x) => ALPHABET[x % ALPHABET.length]).join("");
}

export default {
  async fetch(req, env) {
    const url = new URL(req.url);
    if (req.method === "OPTIONS") return reply(req, null, 204);
    if (req.method === "POST" && url.pathname === "/send") {
      const text = await req.text();
      if (text.length === 0 || text.length > MAX_BYTES) return reply(req, '{"error":"size"}', 413);
      try { JSON.parse(text); } catch { return reply(req, '{"error":"not a save"}', 400); }
      let code = newCode();
      for (let i = 0; i < 4 && (await env.SAVES.get(code)) !== null; i++) code = newCode();
      await env.SAVES.put(code, text, { expirationTtl: TTL });
      return reply(req, JSON.stringify({ code, ttl: TTL }));
    }
    const dm = url.pathname.match(/^\/daily\/(\d{5})$/);
    if (dm) {
      const day = parseInt(dm[1], 10);
      const today = Math.floor(Date.now() / 86400000);
      if (Math.abs(day - today) > 1) return reply(req, '{"error":"day"}', 400);
      const key = "daily:" + day;
      const list = JSON.parse((await env.SAVES.get(key)) || "[]");
      if (req.method === "GET") return reply(req, JSON.stringify({ top: list.slice(0, 20) }));
      if (req.method !== "POST") return reply(req, '{"error":"method"}', 405);
      let entry;
      try { entry = JSON.parse(await req.text()); } catch { return reply(req, '{"error":"json"}', 400); }
      const guild = String(entry.guild || "").replace(/[\u0000-\u001f<>]/g, "").trim().slice(0, 24);
      const score = Math.floor(Number(entry.score));
      const id = String(entry.id || "").replace(/[^a-z0-9]/g, "").slice(0, 16);
      if (!guild || !(score >= 0 && score <= SCORE_MAX)) return reply(req, '{"error":"entry"}', 400);
      // ponytail: read-modify-write on KV (eventually consistent, ~60 s); two posts close together can drop one. A Durable Object fixes that if it ever matters.
      const mine = (e) => (id ? e.id === id : !e.id && e.guild === guild);
      const old = list.find(mine);
      if (old) { old.score = Math.max(old.score, score); old.guild = guild; }
      else list.push(id ? { id, guild, score } : { guild, score });
      list.sort((a, b) => b.score - a.score);
      const kept = list.slice(0, BOARD_SIZE);
      await env.SAVES.put(key, JSON.stringify(kept), { expirationTtl: BOARD_TTL });
      const at = kept.findIndex(mine);
      const top = kept.slice(0, 20).map((e) => ({ guild: e.guild, score: e.score }));   // ids stay on the server
      return reply(req, JSON.stringify({ rank: at >= 0 ? at + 1 : null, top }));
    }
    if (req.method === "POST" && url.pathname === "/m") {
      const text = await req.text();
      if (text.length === 0 || text.length > STATS_MAX) return reply(req, '{"error":"size"}', 413);
      let d;
      try { d = JSON.parse(text); } catch { return reply(req, '{"error":"json"}', 400); }
      const id = String(d.id || "").replace(/[^a-z0-9]/g, "").slice(0, 16);
      if (!id) return reply(req, '{"error":"id"}', 400);
      d.at = new Date().toISOString();
      await env.SAVES.put("m:" + id, JSON.stringify(d), { expirationTtl: STATS_TTL });
      return reply(req, '{"ok":true}');
    }
    const m = url.pathname.match(/^\/take\/([A-Za-z0-9]{6})$/);
    if (req.method === "GET" && m) {
      const code = m[1].toUpperCase();
      const text = await env.SAVES.get(code);
      if (text === null) return reply(req, '{"error":"expired"}', 404);
      await env.SAVES.delete(code);
      return reply(req, text);
    }
    return reply(req, '{"error":"not found"}', 404);
  },
};
