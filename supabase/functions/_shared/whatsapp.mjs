export function normalizePhone(value) {
  if (typeof value !== "string" || value.length > 40) return null;
  const phone = value.trim().replace(/[ -]/g, "");
  if (/^08[0-9]{8,11}$/.test(phone)) return "+62" + phone.slice(1);
  return /^\+628[0-9]{8,11}$/.test(phone) ? phone : null;
}

export function generateCode() {
  const random = new Uint32Array(1);
  // Rejection sampling avoids bias when reducing to six decimal digits.
  do crypto.getRandomValues(random); while (random[0] >= 4294000000);
  return String(random[0] % 1000000).padStart(6, "0");
}

const encoder = new TextEncoder();

export async function mac(secret, ...parts) {
  const key = await crypto.subtle.importKey(
    "raw", encoder.encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"],
  );
  const signature = await crypto.subtle.sign("HMAC", key, encoder.encode(JSON.stringify(parts)));
  return Array.from(new Uint8Array(signature), (n) => n.toString(16).padStart(2, "0")).join("");
}

export async function authorizedCron(request, secret) {
  if (!secret || secret.length < 32) return false;
  const received = request.headers.get("x-reminder-cron-secret") ?? "";
  const actual = await mac(secret, received);
  const expected = await mac(secret, secret);
  let difference = 0;
  for (let i = 0; i < expected.length; i++) {
    difference |= expected.charCodeAt(i) ^ actual.charCodeAt(i);
  }
  return difference === 0;
}

export function openWA({ url, session, key }, fetcher = fetch) {
  const base = new URL(url);
  if (base.protocol !== "https:" || base.username || base.password ||
      base.pathname !== "/" || base.search || base.hash || !session || !key) {
    throw new Error("gateway_configuration");
  }
  const endpoint = new URL(
    "/api/sessions/" + encodeURIComponent(session) + "/messages/send-text", base,
  );
  return async (phone, text, id) => {
    try {
      const response = await fetcher(endpoint, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-API-Key": key,
          "Idempotency-Key": id,
        },
        body: JSON.stringify({ chatId: phone.slice(1) + "@c.us", text, linkPreview: false }),
        redirect: "error",
        signal: AbortSignal.timeout(15000),
      });
      const body = await response.json().catch(() => null);
      if (response.status === 201) {
        // The message ID may embed the phone number; do not retain or log it.
        return typeof body?.messageId === "string" && body.messageId.trim()
          ? "accepted" : "uncertain";
      }
      if (body?.code === "IDEMPOTENCY_OUTCOME_UNKNOWN" || response.status === 422) {
        return "uncertain";
      }
      if (response.status === 409 || response.status === 429 || response.status >= 500) {
        return "retry";
      }
      return "failed";
    } catch {
      return "retry";
    }
  };
}

export function gatewayFromEnv(env) {
  return openWA({
    url: env.get("OPENWA_URL"), session: env.get("OPENWA_SESSION_ID"), key: env.get("OPENWA_API_KEY"),
  });
}

export function supabaseBackend(env, fetcher = fetch) {
  const url = env.get("SUPABASE_URL");
  const key = env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) throw new Error("database_configuration");
  async function call(path, { method = "GET", body, authorization = "Bearer " + key } = {}) {
    return await fetcher(url + path, {
      method,
      headers: { apikey: key, Authorization: authorization, "Content-Type": "application/json" },
      body: body === undefined ? undefined : JSON.stringify(body),
      signal: AbortSignal.timeout(10000),
      redirect: "error",
    });
  }
  async function data(response) {
    if (!response.ok) throw new Error("database_request");
    const text = await response.text();
    return text ? JSON.parse(text) : null;
  }
  return {
    async user(authorization) {
      if (!authorization?.startsWith("Bearer ")) return null;
      const response = await call("/auth/v1/user", { authorization });
      if ([400, 401, 403].includes(response.status)) return null;
      return (await data(response))?.id ?? null;
    },
    async settings(user) {
      const query = new URLSearchParams({
        user_id: "eq." + user, select: "phone,verified_at,enabled,challenge_id,expires_at,attempts",
      });
      return (await data(await call("/rest/v1/whatsapp_settings?" + query)))[0] ?? null;
    },
    async rpc(name, body = {}) {
      return await data(await call("/rest/v1/rpc/" + name, { method: "POST", body }));
    },
  };
}

export const json = (data, status = 200, headers = {}) => Response.json(data, {
  status, headers: { ...headers, "Cache-Control": "no-store" },
});
