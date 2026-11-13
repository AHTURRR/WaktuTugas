import { generateCode, json, mac, normalizePhone } from "../_shared/whatsapp.mjs";

export function settingsHandler(backend, send, secret, newCode = generateCode) {
  const cors = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };
  const reply = (data, status) => json(data, status, cors);
  function view(row) {
    return {
      phone: row?.phone ? "+62••••" + row.phone.slice(-4) : null,
      verified: row?.verified_at != null,
      enabled: row?.enabled === true,
      awaiting_code: row?.challenge_id != null && row.attempts < 5 &&
        Date.parse(row.expires_at) > Date.now(),
    };
  }
  return async (request) => {
    if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });
    if (request.method !== "POST") return reply({ error: "method_not_allowed" }, 405);
    try {
      const user = await backend.user(request.headers.get("authorization"));
      if (!user) return reply({ error: "unauthenticated" }, 401);
      const input = await request.json().catch(() => null);
      if (input?.action === "status") return reply(view(await backend.settings(user)));
      if (input?.action === "enable" && typeof input.enabled === "boolean") {
        const changed = await backend.rpc("whatsapp_set_enabled", {
          p_user: user, p_enabled: input.enabled,
        });
        if (!changed) return reply({ error: "verification_required" }, 409);
        return reply(view(await backend.settings(user)));
      }
      if (input?.action === "request_code" || input?.action === "resend_code") {
        const phone = input.action === "resend_code"
          ? (await backend.settings(user))?.phone : normalizePhone(input.phone);
        if (!phone) return reply({ error: "invalid_phone" }, 400);
        if (!secret || secret.length < 32) throw new Error("verification_configuration");
        const challenge = crypto.randomUUID();
        const code = newCode();
        const result = await backend.rpc("whatsapp_request_code", {
          p_user: user, p_phone: phone, p_phone_mac: await mac(secret, "phone", phone),
          p_challenge: challenge, p_code_mac: await mac(secret, "code", user, challenge, code),
        });
        if (result === "rate_limited") return reply({ error: result }, 429);
        if (result === "issued") {
          const outcome = await send(phone,
            "Kode verifikasi WaktuTugas: " + code + ". Berlaku 10 menit. Jangan bagikan kode ini.",
            "wt-verify-" + challenge,
          );
          if (outcome !== "accepted") {
            return reply({ ...view(await backend.settings(user)), error: "gateway_unconfirmed" }, 502);
          }
        } else if (result !== "already_verified") {
          return reply({ error: "invalid_phone" }, 400);
        }
        return reply(view(await backend.settings(user)));
      }
      if (input?.action === "verify_code") {
        if (typeof input.code !== "string" || !/^\d{6}$/.test(input.code)) {
          return reply({ error: "invalid_code" }, 400);
        }
        const row = await backend.settings(user);
        if (!row?.challenge_id) return reply({ ...view(row), error: "expired" }, 409);
        if (!secret || secret.length < 32) throw new Error("verification_configuration");
        const result = await backend.rpc("whatsapp_verify_code", {
          p_user: user, p_challenge: row.challenge_id,
          p_code_mac: await mac(secret, "code", user, row.challenge_id, input.code),
        });
        const settings = view(await backend.settings(user));
        return result === "verified" ? reply(settings) : reply({ ...settings, error: result }, 409);
      }
      return reply({ error: "invalid_request" }, 400);
    } catch {
      // Never log an upstream exception, request body, or gateway response.
      return reply({ error: "temporarily_unavailable" }, 503);
    }
  };
}
