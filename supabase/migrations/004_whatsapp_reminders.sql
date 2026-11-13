CREATE TABLE public.whatsapp_settings (
    user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    phone text NOT NULL CHECK (phone ~ '^\+628[0-9]{8,11}$'),
    verified_at timestamptz,
    enabled boolean NOT NULL DEFAULT false CHECK (NOT enabled OR verified_at IS NOT NULL),
    challenge_id uuid,
    code_mac text,
    expires_at timestamptz,
    attempts integer NOT NULL DEFAULT 0 CHECK (attempts BETWEEN 0 AND 5)
);

CREATE TABLE public.whatsapp_code_requests (
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    phone_mac text NOT NULL,
    requested_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ON public.whatsapp_code_requests (user_id, requested_at);
CREATE INDEX ON public.whatsapp_code_requests (phone_mac, requested_at);
CREATE INDEX ON public.whatsapp_code_requests (requested_at);

CREATE TABLE public.whatsapp_deliveries (
    task_id uuid NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
    deadline_at timestamptz NOT NULL,
    id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    status text NOT NULL DEFAULT 'queued'
        CHECK (status IN ('queued', 'sending', 'accepted', 'failed', 'uncertain', 'skipped')),
    attempt integer NOT NULL DEFAULT 0,
    available_at timestamptz NOT NULL DEFAULT now(),
    lease uuid,
    recipient_verified_at timestamptz,
    message_title text,
    accepted_at timestamptz,
    PRIMARY KEY (task_id, deadline_at)
);
CREATE INDEX ON public.whatsapp_deliveries (available_at) WHERE status IN ('queued', 'sending');
CREATE INDEX ON public.tasks (deadline_at) WHERE remaining_minutes > 0;

ALTER TABLE public.whatsapp_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.whatsapp_code_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.whatsapp_deliveries ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.whatsapp_settings, public.whatsapp_code_requests, public.whatsapp_deliveries
    FROM PUBLIC, anon, authenticated;
GRANT SELECT (user_id, phone, verified_at, enabled) ON public.whatsapp_settings TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.whatsapp_settings,
    public.whatsapp_code_requests, public.whatsapp_deliveries TO service_role;
CREATE POLICY whatsapp_own_settings ON public.whatsapp_settings FOR SELECT
    TO authenticated USING (auth.uid() = user_id);

CREATE FUNCTION public.whatsapp_request_code(
    p_user uuid, p_phone text, p_phone_mac text, p_challenge uuid, p_code_mac text
) RETURNS text LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE
    v_settings public.whatsapp_settings%ROWTYPE;
BEGIN
    IF p_phone IS NULL OR p_phone !~ '^\+628[0-9]{8,11}$' THEN
        RETURN 'invalid_phone';
    END IF;
    PERFORM pg_advisory_xact_lock(hashtextextended(p_user::text, 0));
    PERFORM pg_advisory_xact_lock(hashtextextended(p_phone_mac, 1));
    SELECT * INTO v_settings FROM public.whatsapp_settings WHERE user_id = p_user FOR UPDATE;
    IF v_settings.phone = p_phone AND v_settings.verified_at IS NOT NULL THEN
        RETURN 'already_verified';
    END IF;
    IF EXISTS (
        SELECT 1 FROM public.whatsapp_code_requests
        WHERE user_id = p_user AND requested_at > now() - interval '1 minute'
    ) OR (
        SELECT count(*) FROM public.whatsapp_code_requests
        WHERE user_id = p_user AND requested_at > now() - interval '1 hour'
    ) >= 3 OR (
        SELECT count(*) FROM public.whatsapp_code_requests
        WHERE phone_mac = p_phone_mac AND requested_at > now() - interval '1 hour'
    ) >= 3 THEN
        RETURN 'rate_limited';
    END IF;

    DELETE FROM public.whatsapp_code_requests WHERE requested_at <= now() - interval '1 hour';
    INSERT INTO public.whatsapp_code_requests(user_id, phone_mac) VALUES (p_user, p_phone_mac);
    INSERT INTO public.whatsapp_settings(user_id, phone, challenge_id, code_mac, expires_at)
    VALUES (p_user, p_phone, p_challenge, p_code_mac, now() + interval '10 minutes')
    ON CONFLICT (user_id) DO UPDATE SET
        phone = excluded.phone, verified_at = NULL, enabled = false,
        challenge_id = excluded.challenge_id, code_mac = excluded.code_mac,
        expires_at = excluded.expires_at, attempts = 0;
    RETURN 'issued';
END;
$$;

CREATE FUNCTION public.whatsapp_verify_code(p_user uuid, p_challenge uuid, p_code_mac text)
RETURNS text LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE
    v_settings public.whatsapp_settings%ROWTYPE;
BEGIN
    SELECT * INTO v_settings FROM public.whatsapp_settings WHERE user_id = p_user FOR UPDATE;
    IF v_settings.challenge_id IS NULL OR v_settings.challenge_id IS DISTINCT FROM p_challenge
        OR v_settings.expires_at <= now() THEN
        RETURN 'expired';
    END IF;
    IF v_settings.attempts >= 5 THEN RETURN 'attempts_exhausted'; END IF;
    IF v_settings.code_mac IS DISTINCT FROM p_code_mac THEN
        UPDATE public.whatsapp_settings SET attempts = attempts + 1,
            code_mac = CASE WHEN attempts = 4 THEN NULL ELSE code_mac END
        WHERE user_id = p_user;
        RETURN CASE WHEN v_settings.attempts = 4 THEN 'attempts_exhausted' ELSE 'wrong_code' END;
    END IF;
    UPDATE public.whatsapp_settings
    SET verified_at = clock_timestamp(), challenge_id = NULL, code_mac = NULL,
        expires_at = NULL, attempts = 0
    WHERE user_id = p_user;
    RETURN 'verified';
END;
$$;

CREATE FUNCTION public.whatsapp_set_enabled(p_user uuid, p_enabled boolean)
RETURNS boolean LANGUAGE sql SET search_path = '' AS $$
    WITH changed AS (
        UPDATE public.whatsapp_settings SET enabled = p_enabled
        WHERE user_id = p_user AND (NOT p_enabled OR verified_at IS NOT NULL)
        RETURNING 1
    )
    SELECT NOT p_enabled OR EXISTS (SELECT 1 FROM changed);
$$;

-- Only the 15 minutes following the 24-hour mark are eligible. This also
-- bounds retries well inside OpenWA's 24-hour idempotency retention.
CREATE FUNCTION public.whatsapp_claim_reminders()
RETURNS TABLE (id uuid, lease uuid) LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
    UPDATE public.whatsapp_deliveries d
    SET status = CASE WHEN d.attempt > 0 THEN 'uncertain' ELSE 'skipped' END, lease = NULL
    WHERE d.status IN ('queued', 'sending') AND d.available_at <= now()
        AND d.deadline_at <= now() + interval '23 hours 45 minutes';

    INSERT INTO public.whatsapp_deliveries(task_id, deadline_at)
    SELECT t.id, t.deadline_at FROM public.tasks t
    JOIN public.whatsapp_settings s ON s.user_id = t.user_id
    WHERE t.remaining_minutes > 0 AND s.enabled AND s.verified_at IS NOT NULL
        AND t.deadline_at <= now() + interval '24 hours'
        AND t.deadline_at > now() + interval '23 hours 45 minutes'
        AND NOT EXISTS (SELECT 1 FROM public.whatsapp_deliveries d
            WHERE d.task_id = t.id AND d.deadline_at = t.deadline_at)
    ORDER BY t.deadline_at, t.id
    LIMIT 100
    ON CONFLICT (task_id, deadline_at) DO NOTHING;

    RETURN QUERY
    WITH due AS (
        SELECT d.id FROM public.whatsapp_deliveries d
        WHERE d.status IN ('queued', 'sending') AND d.available_at <= now()
            AND d.deadline_at > now() + interval '23 hours 45 minutes'
        ORDER BY d.available_at, d.id
        LIMIT 10 FOR UPDATE SKIP LOCKED
    )
    UPDATE public.whatsapp_deliveries d SET status = 'sending',
        lease = gen_random_uuid(), attempt = d.attempt + 1, available_at = now() + interval '2 minutes'
    FROM due WHERE d.id = due.id RETURNING d.id, d.lease;
END;
$$;

CREATE FUNCTION public.whatsapp_prepare_reminder(p_id uuid, p_lease uuid)
RETURNS TABLE (phone text, title text, deadline_at timestamptz) LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
    RETURN QUERY
    UPDATE public.whatsapp_deliveries d
    SET recipient_verified_at = s.verified_at, message_title = coalesce(d.message_title, t.title)
    FROM public.tasks t JOIN public.whatsapp_settings s ON s.user_id = t.user_id
    WHERE d.id = p_id AND d.lease = p_lease AND d.status = 'sending'
        AND d.available_at > now() AND d.attempt <= 4
        AND d.task_id = t.id AND d.deadline_at = t.deadline_at AND t.remaining_minutes > 0
        AND t.deadline_at <= now() + interval '24 hours'
        AND t.deadline_at > now() + interval '23 hours 45 minutes'
        AND s.enabled AND s.verified_at IS NOT NULL
        AND (d.recipient_verified_at IS NULL OR d.recipient_verified_at = s.verified_at)
    RETURNING s.phone, d.message_title, d.deadline_at;

    IF NOT FOUND THEN
        UPDATE public.whatsapp_deliveries d SET status = CASE
            WHEN d.recipient_verified_at IS NULL THEN 'skipped' ELSE 'uncertain' END, lease = NULL
        WHERE d.id = p_id AND d.lease = p_lease AND d.status = 'sending';
    END IF;
END;
$$;

CREATE FUNCTION public.whatsapp_finish_reminder(p_id uuid, p_lease uuid, p_outcome text)
RETURNS void LANGUAGE sql SET search_path = '' AS $$
    UPDATE public.whatsapp_deliveries
    SET status = CASE WHEN p_outcome = 'retry' THEN
            CASE WHEN attempt < 4 THEN 'queued' ELSE 'uncertain' END ELSE p_outcome END,
        lease = NULL, available_at = now() + interval '1 minute',
        accepted_at = CASE WHEN p_outcome = 'accepted' THEN now() ELSE NULL END
    WHERE id = p_id AND lease = p_lease AND status = 'sending'
        AND p_outcome IN ('accepted', 'retry', 'failed', 'uncertain');
$$;

REVOKE EXECUTE ON FUNCTION
    public.whatsapp_request_code(uuid, text, text, uuid, text),
    public.whatsapp_verify_code(uuid, uuid, text),
    public.whatsapp_set_enabled(uuid, boolean),
    public.whatsapp_claim_reminders(),
    public.whatsapp_prepare_reminder(uuid, uuid),
    public.whatsapp_finish_reminder(uuid, uuid, text)
FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION
    public.whatsapp_request_code(uuid, text, text, uuid, text),
    public.whatsapp_verify_code(uuid, uuid, text),
    public.whatsapp_set_enabled(uuid, boolean),
    public.whatsapp_claim_reminders(),
    public.whatsapp_prepare_reminder(uuid, uuid),
    public.whatsapp_finish_reminder(uuid, uuid, text)
TO service_role;
