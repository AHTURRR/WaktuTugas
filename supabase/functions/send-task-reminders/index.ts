import { gatewayFromEnv, supabaseBackend } from "../_shared/whatsapp.mjs";
import { remindersHandler } from "./handler.mjs";

Deno.serve(remindersHandler(
  supabaseBackend(Deno.env), (...args: [string, string, string]) => gatewayFromEnv(Deno.env)(...args),
  Deno.env.get("WHATSAPP_CRON_SECRET"),
));
