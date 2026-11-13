import { gatewayFromEnv, supabaseBackend } from "../_shared/whatsapp.mjs";
import { settingsHandler } from "./handler.mjs";

Deno.serve(settingsHandler(
  supabaseBackend(Deno.env), (...args: [string, string, string]) => gatewayFromEnv(Deno.env)(...args),
  Deno.env.get("WHATSAPP_CODE_SECRET"),
));
