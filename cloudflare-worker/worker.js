/**
 * Grok Translate – Cloudflare Worker WebSocket Proxy
 * ====================================================
 *
 * PURPOSE
 * -------
 * This worker is the SOLE holder of the XAI_API_KEY secret.
 * No API key is ever stored on user devices — all platforms (web, iOS,
 * Android) connect to this proxy, which injects the Authorization header
 * before forwarding requests to the Grok API.
 *
 * DEPLOY INSTRUCTIONS
 * -------------------
 * Option A – Cloudflare Dashboard (quickest):
 *   1. Go to https://dash.cloudflare.com → Workers & Pages → Create Worker
 *   2. Paste this entire file into the editor and click "Save and Deploy".
 *   3. Go to Settings → Variables → add a Secret named:
 *        XAI_API_KEY = your actual xAI key (e.g. xai-xxxxxxxxxxxx)
 *   4. Deploy again to pick up the secret.
 *
 * Option B – Wrangler CLI:
 *   npm install -g wrangler
 *   wrangler login
 *   wrangler secret put XAI_API_KEY
 *   wrangler deploy
 *
 * HOW IT WORKS
 * ------------
 * Client (Flutter web/iOS/Android) ──WS──▶ This Worker ──WS──▶ api.x.ai
 *
 * The worker upgrades the incoming HTTP request to a WebSocket pair,
 * opens a second WebSocket to the Grok API with the secret Authorization
 * header, then pipes frames bidirectionally until either side closes.
 *
 * ORIGIN POLICY
 * -------------
 * Web browsers send an Origin header — checked against ALLOWED_WEB_ORIGINS.
 * Native mobile apps (iOS/Android) do NOT send an Origin header. These
 * requests are allowed through without an origin check because:
 *   - The XAI_API_KEY is still never exposed to the client.
 *   - Abuse is rate-limited by xAI on the API side.
 * If you need stricter controls, add a shared secret header to native clients
 * and verify it here.
 */

// ─── Configuration ────────────────────────────────────────────────────────────

// Grok Realtime API endpoint (translator mode).
const GROK_API_URL = "https://api.x.ai/v1/realtime?model=grok-voice-think-fast-1.0";

// Grok STT streaming endpoint (subtitles mode — real-time partial transcripts).
const GROK_STT_BASE = "https://api.x.ai/v1/stt";

// Grok chat completions endpoint (subtitles translation via REST).
const GROK_CHAT_URL = "https://api.x.ai/v1/chat/completions";

/**
 * Origins explicitly allowed for browser (web) clients.
 * Add your production domain(s) here.
 * localhost and Cloudflare preview domains are always allowed (see isAllowedOrigin).
 *
 * Example:
 *   "https://grok-translate.pages.dev",
 *   "https://translate.mycompany.com",
 */
const ALLOWED_WEB_ORIGINS = new Set([
  // ── Add your production domain(s) here ────────────────────────────────
  // "https://grok-translate.pages.dev",
]);

// ─── Main Handler ─────────────────────────────────────────────────────────────

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const origin = request.headers.get("Origin") ?? "";

    // ── 1. CORS preflight ──────────────────────────────────────────────────
    if (request.method === "OPTIONS") {
      return corsPreflightResponse(origin);
    }

    // ── 2. Health-check endpoint ───────────────────────────────────────────
    if (url.pathname === "/health") {
      return jsonResponse({ status: "ok", service: "grok-translate-proxy" });
    }

    // ── 3. Translation REST proxy (subtitles mode) ─────────────────────────
    // POST /translate  →  POST https://api.x.ai/v1/chat/completions
    if (url.pathname === "/translate" && request.method === "POST") {
      if (!isAllowedOrigin(origin)) {
        return new Response("Forbidden: origin not allowed", { status: 403 });
      }
      if (!env.XAI_API_KEY) {
        return new Response("Internal Server Error: proxy not configured", { status: 500 });
      }
      const body = await request.text();
      const upstream = await fetch(GROK_CHAT_URL, {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${env.XAI_API_KEY}`,
          "Content-Type": "application/json",
        },
        body,
      });
      const text = await upstream.text();
      return new Response(text, {
        status: upstream.status,
        headers: {
          "Content-Type": "application/json",
          ...securityHeaders(origin),
        },
      });
    }

    // ── 4. STT WebSocket proxy (subtitles mode real-time captions) ─────────
    // GET /stt[?params]  →  wss://api.x.ai/v1/stt[?params]
    if (url.pathname === "/stt") {
      if (!isAllowedOrigin(origin)) {
        return new Response("Forbidden: origin not allowed", { status: 403 });
      }
      if (!env.XAI_API_KEY) {
        return new Response("Internal Server Error: proxy not configured", { status: 500 });
      }
      const { 0: clientSocket, 1: serverSide } = new WebSocketPair();
      serverSide.accept();

      // Forward the query string (sample_rate, encoding, interim_results, etc.)
      const sttUrl = `${GROK_STT_BASE}${url.search}`;
      let sttSocket;
      try {
        const sttResp = await fetch(sttUrl, {
          headers: {
            "Upgrade": "websocket",
            "Connection": "Upgrade",
            "Authorization": `Bearer ${env.XAI_API_KEY}`,
            "Sec-WebSocket-Version": "13",
          },
        });
        if (sttResp.status !== 101) {
          const body = await sttResp.text();
          serverSide.close(1011, "STT upstream failed");
          return new Response(`STT refused: ${sttResp.status} – ${body}`, { status: 502 });
        }
        sttSocket = sttResp.webSocket;
        sttSocket.accept();
      } catch (err) {
        serverSide.close(1011, "STT upstream unreachable");
        return new Response("Bad Gateway", { status: 502 });
      }

      // Client → STT (binary audio frames)
      serverSide.addEventListener("message", (evt) => {
        try { sttSocket.send(evt.data); } catch (_) {}
      });
      // STT → Client (JSON transcript events)
      sttSocket.addEventListener("message", (evt) => {
        try { serverSide.send(evt.data); } catch (_) {}
      });
      serverSide.addEventListener("close", (evt) => {
        try { sttSocket.close(evt.code, evt.reason); } catch (_) {}
      });
      sttSocket.addEventListener("close", (evt) => {
        try { serverSide.close(evt.code, evt.reason); } catch (_) {}
      });

      return new Response(null, {
        status: 101,
        webSocket: clientSocket,
        headers: securityHeaders(origin),
      });
    }

    // ── 5. Custom voices list (GET /custom-voices) ────────────────────────
    // GET /custom-voices  →  GET https://api.x.ai/v1/custom-voices
    // Lets the app show the user's cloned voice list in Settings.
    if (url.pathname === "/custom-voices" && request.method === "GET") {
      if (!isAllowedOrigin(origin)) {
        return new Response("Forbidden: origin not allowed", { status: 403 });
      }
      if (!env.XAI_API_KEY) {
        return new Response("Internal Server Error: proxy not configured", { status: 500 });
      }
      // Forward optional query params (limit, pagination_token)
      const xaiUrl = `https://api.x.ai/v1/custom-voices${url.search}`;
      const upstream = await fetch(xaiUrl, {
        headers: { "Authorization": `Bearer ${env.XAI_API_KEY}` },
      });
      const body = await upstream.text();
      return new Response(body, {
        status: upstream.status,
        headers: {
          "Content-Type": "application/json",
          ...securityHeaders(origin),
        },
      });
    }

    // ── 6. Only accept WebSocket upgrades beyond this point ───────────────
    const upgradeHeader = request.headers.get("Upgrade");
    const wsKey = request.headers.get("Sec-WebSocket-Key");
    const isWebSocket =
      (upgradeHeader && upgradeHeader.toLowerCase() === "websocket") || !!wsKey;
    if (!isWebSocket) {
      return jsonResponse(
        { error: "This endpoint only accepts WebSocket connections." },
        426,
        { "Upgrade": "websocket" }
      );
    }

    // ── 7. Origin validation (web browsers only) ──────────────────────────
    // Native mobile clients send no Origin header — allow them through.
    // Browser clients must match ALLOWED_WEB_ORIGINS or known safe patterns.
    if (origin && !isAllowedOrigin(origin)) {
      console.warn(`[proxy] Rejected browser origin: ${origin}`);
      return new Response("Forbidden: origin not allowed", { status: 403 });
    }

    // ── 8. API key check ──────────────────────────────────────────────────
    if (!env.XAI_API_KEY) {
      console.error("[proxy] XAI_API_KEY secret is not set.");
      return new Response("Internal Server Error: proxy not configured", {
        status: 500,
      });
    }

    // ── 9. Upgrade the client connection ──────────────────────────────────
    const { 0: clientSocket, 1: serverSide } = new WebSocketPair();
    serverSide.accept();

    // ── 10. Upgrade the upstream Grok connection (with the secret header) ──
    let grokSocket;
    try {
      const grokResp = await fetch(GROK_API_URL, {
        headers: {
          "Upgrade": "websocket",
          "Connection": "Upgrade",
          "Authorization": `Bearer ${env.XAI_API_KEY}`,
          "Sec-WebSocket-Version": "13",
          ...(request.headers.get("Sec-WebSocket-Protocol")
            ? { "Sec-WebSocket-Protocol": request.headers.get("Sec-WebSocket-Protocol") }
            : {}),
        },
      });

      if (grokResp.status !== 101) {
        const body = await grokResp.text();
        const msg = `Grok refused: ${grokResp.status} – ${body}`;
        console.error(`[proxy] ${msg}`);
        serverSide.close(1011, "Upstream connection failed");
        return new Response(msg, { status: 502 });
      }

      grokSocket = grokResp.webSocket;
      grokSocket.accept();
    } catch (err) {
      console.error("[proxy] Failed to connect to Grok API:", err);
      serverSide.close(1011, "Upstream unreachable");
      return new Response("Bad Gateway", { status: 502 });
    }

    // ── 11. Bidirectional pipe ─────────────────────────────────────────────

    // Client → Grok
    serverSide.addEventListener("message", (evt) => {
      try {
        grokSocket.send(evt.data);
      } catch (err) {
        console.warn("[proxy] Failed to forward client→grok:", err);
      }
    });

    // Grok → Client
    grokSocket.addEventListener("message", (evt) => {
      try {
        serverSide.send(evt.data);
      } catch (err) {
        console.warn("[proxy] Failed to forward grok→client:", err);
      }
    });

    // Close propagation: client closed → close grok
    serverSide.addEventListener("close", (evt) => {
      console.log(`[proxy] Client closed (${evt.code}). Closing upstream.`);
      try { grokSocket.close(evt.code, evt.reason); } catch (_) {}
    });

    // Close propagation: grok closed → close client
    grokSocket.addEventListener("close", (evt) => {
      console.log(`[proxy] Upstream closed (${evt.code}). Closing client.`);
      try { serverSide.close(evt.code, evt.reason); } catch (_) {}
    });

    serverSide.addEventListener("error", (err) => {
      console.error("[proxy] Client socket error:", err);
    });
    grokSocket.addEventListener("error", (err) => {
      console.error("[proxy] Grok socket error:", err);
    });

    // ── 12. Return the 101 Switching Protocols response to the client ──────
    return new Response(null, {
      status: 101,
      webSocket: clientSocket,
      headers: securityHeaders(origin),
    });
  },
};

// ─── Helpers ──────────────────────────────────────────────────────────────────

/**
 * Returns true for:
 *   - Empty/null origin (native mobile apps — no Origin header sent)
 *   - Explicitly listed origins in ALLOWED_WEB_ORIGINS
 *   - Any localhost port (local Flutter web dev)
 *   - Cloudflare preview domains (*.pages.dev, *.workers.dev, *.trycloudflare.com)
 */
function isAllowedOrigin(origin) {
  if (!origin) return true; // native mobile clients have no Origin header
  if (ALLOWED_WEB_ORIGINS.has(origin)) return true;
  try {
    const u = new URL(origin);
    if (u.hostname === "localhost" || u.hostname === "127.0.0.1") return true;
    if (u.hostname.endsWith(".trycloudflare.com")) return true;
    if (u.hostname.endsWith(".pages.dev")) return true;
    if (u.hostname.endsWith(".workers.dev")) return true;
  } catch (_) {}
  return false;
}

function corsPreflightResponse(origin) {
  return new Response(null, {
    status: 204,
    headers: {
      ...securityHeaders(origin),
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Upgrade, Connection, Sec-WebSocket-Protocol, Sec-WebSocket-Key, Sec-WebSocket-Version",
      "Access-Control-Max-Age": "86400",
    },
  });
}

function securityHeaders(origin) {
  return {
    "Access-Control-Allow-Origin": isAllowedOrigin(origin) ? (origin || "*") : "null",
    "Access-Control-Allow-Credentials": "true",
    "X-Content-Type-Options": "nosniff",
    "X-Frame-Options": "DENY",
    "Referrer-Policy": "strict-origin-when-cross-origin",
  };
}

function jsonResponse(body, status = 200, extraHeaders = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...extraHeaders,
    },
  });
}

/*
 * ─── wrangler.toml (for CLI deploy) ──────────────────────────────────────────
 *
 * name = "grok-translate-proxy"
 * main = "worker.js"
 * compatibility_date = "2025-01-01"
 * compatibility_flags = ["nodejs_compat"]
 *
 * Then run:
 *   wrangler secret put XAI_API_KEY
 *   wrangler deploy
 *
 * ─────────────────────────────────────────────────────────────────────────────
 */
