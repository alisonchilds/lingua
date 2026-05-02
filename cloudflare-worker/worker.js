/**
 * Grok Translate – Cloudflare Worker WebSocket Proxy
 * ====================================================
 *
 * DEPLOY INSTRUCTIONS
 * -------------------
 * Option A – Cloudflare Dashboard (quickest):
 *   1. Go to https://dash.cloudflare.com → Workers & Pages → Create Application → Create Worker
 *   2. Paste this entire file into the editor.
 *   3. Click "Save and Deploy".
 *   4. Go to Settings → Variables → add a Secret named:
 *        XAI_API_KEY = your actual xAI key (e.g. xai-xxxxxxxxxxxx)
 *   5. Under Settings → Triggers, note your worker URL:
 *        e.g.  grok-translate-proxy.YOUR-SUBDOMAIN.workers.dev
 *   6. Replace YOUR_APP_DOMAIN below with your actual production domain,
 *      e.g. "grok-translate.pages.dev" or your custom domain.
 *   7. Deploy again to pick up the domain change.
 *
 * Option B – Wrangler CLI:
 *   npm install -g wrangler
 *   wrangler login
 *   # Add wrangler.toml (see bottom of this file), then:
 *   wrangler secret put XAI_API_KEY
 *   wrangler deploy
 *
 * HOW IT WORKS
 * ------------
 * Client (Flutter web/mobile) ──WS──▶ This Worker ──WS──▶ api.x.ai
 *
 * The worker upgrades the incoming HTTP request to a WebSocket pair,
 * opens a second WebSocket to the Grok API with the secret Authorization
 * header, then pipes frames bidirectionally until either side closes.
 * The Flutter app never sees the API key.
 */

// ─── Configuration ────────────────────────────────────────────────────────────

// Grok Realtime API endpoint.
// IMPORTANT: Cloudflare Workers require https:// (not wss://) when calling
// fetch() to establish an upstream WebSocket — the runtime upgrades it automatically.
const GROK_API_URL = "https://api.x.ai/v1/realtime?model=grok-voice-think-fast-1.0";

/**
 * Origins allowed to connect to this proxy.
 * Replace YOUR_APP_DOMAIN with your real production domain.
 * Keep localhost entries for local Flutter web development.
 */
const ALLOWED_ORIGINS = new Set([
  // ── Production ────────────────────────────────────────────────────────────
  "https://YOUR_APP_DOMAIN",          // ← replace with your production domain
  // ── Local development ─────────────────────────────────────────────────────
  "http://localhost:3000",
  "http://localhost:8080",
  "http://localhost:5000",
  // ── Cloudflare Tunnel (dev preview) ───────────────────────────────────────
  // Add your trycloudflare.com URL here if you want the tunnel to work with
  // the deployed worker (the localhost check below covers it automatically).
  // "https://your-tunnel-id.trycloudflare.com",
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

    // ── 3. Only accept WebSocket upgrades beyond this point ───────────────
    const upgradeHeader = request.headers.get("Upgrade");
    if (!upgradeHeader || upgradeHeader.toLowerCase() !== "websocket") {
      return jsonResponse(
        { error: "This endpoint only accepts WebSocket connections." },
        426, // Upgrade Required
        { "Upgrade": "websocket" }
      );
    }

    // ── 4. Origin validation ───────────────────────────────────────────────
    if (!isAllowedOrigin(origin)) {
      console.warn(`[proxy] Rejected origin: ${origin}`);
      return new Response("Forbidden: origin not allowed", { status: 403 });
    }

    // ── 5. API key check (fail fast if secret not configured) ──────────────
    if (!env.XAI_API_KEY) {
      console.error("[proxy] XAI_API_KEY secret is not set.");
      return new Response("Internal Server Error: proxy not configured", {
        status: 500,
      });
    }

    // ── 6. Upgrade the client connection ──────────────────────────────────
    const { 0: clientSocket, 1: serverSide } = new WebSocketPair();
    serverSide.accept();

    // ── 7. Upgrade the upstream Grok connection (with the secret header) ───
    let grokSocket;
    try {
      // Cloudflare Workers use https:// for upstream WebSocket fetches.
      // The `Upgrade: websocket` header tells the runtime to upgrade the
      // connection. HTTP/2 does not support Upgrade, so this only works
      // because Workers' fetch() internally uses HTTP/1.1 for WS upgrades.
      const grokResp = await fetch(GROK_API_URL, {
        headers: {
          "Upgrade": "websocket",
          "Connection": "Upgrade",
          "Authorization": `Bearer ${env.XAI_API_KEY}`,
          "Sec-WebSocket-Version": "13",
          // Forward subprotocol if the client sent one
          ...(request.headers.get("Sec-WebSocket-Protocol")
            ? { "Sec-WebSocket-Protocol": request.headers.get("Sec-WebSocket-Protocol") }
            : {}),
        },
      });

      if (grokResp.status !== 101) {
        const body = await grokResp.text();
        console.error(`[proxy] Grok API refused upgrade: ${grokResp.status} – ${body}`);
        serverSide.close(1011, "Upstream connection failed");
        return new Response("Bad Gateway: upstream refused WebSocket upgrade", {
          status: 502,
        });
      }

      grokSocket = grokResp.webSocket;
      grokSocket.accept();
    } catch (err) {
      console.error("[proxy] Failed to connect to Grok API:", err);
      serverSide.close(1011, "Upstream unreachable");
      return new Response("Bad Gateway", { status: 502 });
    }

    // ── 8. Bidirectional pipe ─────────────────────────────────────────────

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

    // Error handling
    serverSide.addEventListener("error", (err) => {
      console.error("[proxy] Client socket error:", err);
    });
    grokSocket.addEventListener("error", (err) => {
      console.error("[proxy] Grok socket error:", err);
    });

    // ── 9. Return the 101 Switching Protocols response to the client ───────
    return new Response(null, {
      status: 101,
      webSocket: clientSocket,
      headers: securityHeaders(origin),
    });
  },
};

// ─── Helpers ──────────────────────────────────────────────────────────────────

/**
 * Returns true for explicitly allowed origins AND for any localhost port
 * (convenient for local Flutter web dev without listing every port).
 */
function isAllowedOrigin(origin) {
  if (!origin) return false;
  if (ALLOWED_ORIGINS.has(origin)) return true;
  try {
    const u = new URL(origin);
    // Allow any localhost regardless of port (local Flutter web dev)
    if (u.hostname === "localhost" || u.hostname === "127.0.0.1") return true;
    // Allow all Cloudflare-owned preview domains
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
      "Access-Control-Allow-Methods": "GET, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Upgrade, Connection, Sec-WebSocket-Protocol, Sec-WebSocket-Key, Sec-WebSocket-Version",
      "Access-Control-Max-Age": "86400",
    },
  });
}

function securityHeaders(origin) {
  return {
    "Access-Control-Allow-Origin": isAllowedOrigin(origin) ? origin : "null",
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
 * ─── wrangler.toml (for Option B – CLI deploy) ───────────────────────────────
 *
 * Create a file called wrangler.toml next to worker.js with this content:
 *
 * name = "grok-translate-proxy"
 * main = "worker.js"
 * compatibility_date = "2025-01-01"
 * compatibility_flags = ["nodejs_compat"]
 *
 * [vars]
 * # Non-secret vars go here. The API key is stored as a secret (never in toml).
 *
 * Then run:
 *   wrangler secret put XAI_API_KEY
 *   wrangler deploy
 *
 * ─────────────────────────────────────────────────────────────────────────────
 */
