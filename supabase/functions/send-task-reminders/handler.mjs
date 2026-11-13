import { authorizedCron, json } from "../_shared/whatsapp.mjs";

const deadlineFormat = new Intl.DateTimeFormat("id-ID", {
  timeZone: "Asia/Jakarta", dateStyle: "long", timeStyle: "short",
});

export function remindersHandler(backend, send, secret) {
  return async (request) => {
    if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405);
    if (!await authorizedCron(request, secret)) return json({ error: "unauthorized" }, 401);
    try {
      const claims = await backend.rpc("whatsapp_claim_reminders");
      const results = await Promise.allSettled(claims.map(async ({ id, lease }) => {
        const args = { p_id: id, p_lease: lease };
        const [item] = await backend.rpc("whatsapp_prepare_reminder", args);
        if (!item) return "skipped";
        const deadline = deadlineFormat.format(new Date(item.deadline_at));
        const outcome = await send(item.phone,
          'Pengingat WaktuTugas: "' + item.title + '" jatuh tempo ' + deadline + ' WIB.',
          "wt-deadline-" + id,
        );
        await backend.rpc("whatsapp_finish_reminder", { ...args, p_outcome: outcome });
        return outcome;
      }));
      const counts = {};
      for (const result of results) {
        const outcome = result.status === "fulfilled" ? result.value : "internal_error";
        counts[outcome] = (counts[outcome] ?? 0) + 1;
      }
      return json(counts, counts.internal_error ? 503 : 200);
    } catch {
      return json({ error: "temporarily_unavailable" }, 503);
    }
  };
}
