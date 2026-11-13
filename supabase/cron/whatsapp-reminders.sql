-- Run once after the function is deployed and both Vault secrets exist.
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM vault.decrypted_secrets
        WHERE name = 'whatsapp_project_url'
            AND decrypted_secret ~ '^https://[a-z0-9]+\.supabase\.co$'
    ) OR NOT EXISTS (
        SELECT 1 FROM vault.decrypted_secrets
        WHERE name = 'whatsapp_cron_secret' AND length(decrypted_secret) >= 32
    ) THEN
        RAISE EXCEPTION 'Set the WhatsApp Cron Vault secrets before scheduling.';
    END IF;
END;
$$;

SELECT cron.schedule('send-task-reminders', '* * * * *', $job$
    SELECT net.http_post(
        url := (SELECT decrypted_secret FROM vault.decrypted_secrets
            WHERE name = 'whatsapp_project_url') || '/functions/v1/send-task-reminders',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'x-reminder-cron-secret', (SELECT decrypted_secret FROM vault.decrypted_secrets
                WHERE name = 'whatsapp_cron_secret')
        ),
        body := '{}'::jsonb,
        timeout_milliseconds := 45000
    );
$job$);
