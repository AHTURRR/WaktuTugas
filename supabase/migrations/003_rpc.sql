-- 003_rpc.sql
-- Prosedur Transaksional Ber-revisi (Atomic RPC Mutators)
-- Berdasarkan PRD_WaktuTugas_Ahmad_Turmudi_60324069.md Bagian 7 & 8

-- ============================================================================
-- 1. Snapshot Pembacaan Bersama
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_planner_snapshot()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    uid uuid;
    current_rev bigint;
    res jsonb;
BEGIN
    uid := auth.uid();
    IF uid IS NULL THEN
        RAISE EXCEPTION 'UNAUTHENTICATED' USING ERRCODE = 'P0001';
    END IF;

    -- Inisialisasi baris planner_state jika belum ada
    INSERT INTO public.planner_state (user_id, revision)
    VALUES (uid, 0)
    ON CONFLICT (user_id) DO NOTHING;

    -- Kunci baca bersama (SHARE)
    SELECT revision INTO current_rev
    FROM public.planner_state
    WHERE user_id = uid
    FOR SHARE;

    SELECT jsonb_build_object(
        'revision', current_rev,
        'tasks', COALESCE((
            SELECT jsonb_agg(
                jsonb_build_object(
                    'id', t.id,
                    'title', t.title,
                    'course', t.course,
                    'deadline_at', t.deadline_at,
                    'remaining_minutes', t.remaining_minutes,
                    'created_at', t.created_at
                ) ORDER BY t.created_at ASC
            ) FROM public.tasks t WHERE t.user_id = uid
        ), '[]'::jsonb),
        'time_windows', COALESCE((
            SELECT jsonb_agg(
                jsonb_build_object(
                    'id', w.id,
                    'weekday', w.weekday,
                    'date', w.date,
                    'start_minute', w.start_minute,
                    'end_minute', w.end_minute
                )
            ) FROM public.time_windows w WHERE w.user_id = uid
        ), '[]'::jsonb),
        'activities', COALESCE((
            SELECT jsonb_agg(
                jsonb_build_object(
                    'id', a.id,
                    'kind', a.kind,
                    'label', a.label,
                    'weekday', a.weekday,
                    'date', a.date,
                    'start_minute', a.start_minute,
                    'end_minute', a.end_minute
                )
            ) FROM public.activities a WHERE a.user_id = uid
        ), '[]'::jsonb),
        'sessions', COALESCE((
            SELECT jsonb_agg(
                jsonb_build_object(
                    'id', s.id,
                    'task_id', s.task_id,
                    'starts_at', s.starts_at,
                    'ends_at', s.ends_at,
                    'status', s.status,
                    'remaining_after', s.remaining_after,
                    'closed_at', s.closed_at
                ) ORDER BY s.starts_at ASC
            ) FROM public.sessions s WHERE s.user_id = uid
        ), '[]'::jsonb)
    ) INTO res;

    RETURN res;
END;
$$;

-- ============================================================================
-- 2. CRUD Tasks
-- ============================================================================
CREATE OR REPLACE FUNCTION public.save_task(
    p_task_id uuid,
    p_title text,
    p_course text,
    p_deadline_at timestamptz,
    p_remaining_minutes integer,
    p_expected_revision bigint
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    uid uuid;
    current_rev bigint;
    new_rev bigint;
BEGIN
    uid := auth.uid();
    IF uid IS NULL THEN
        RAISE EXCEPTION 'UNAUTHENTICATED' USING ERRCODE = 'P0001';
    END IF;

    -- Kunci baris planner_state pengguna
    INSERT INTO public.planner_state (user_id, revision)
    VALUES (uid, 0)
    ON CONFLICT (user_id) DO NOTHING;

    SELECT revision INTO current_rev
    FROM public.planner_state
    WHERE user_id = uid
    FOR UPDATE;

    IF current_rev IS DISTINCT FROM p_expected_revision THEN
        RAISE EXCEPTION 'STALE_REVISION' USING ERRCODE = 'P0002';
    END IF;

    -- Validasi data
    IF p_title IS NULL OR char_length(trim(p_title)) < 1 OR char_length(trim(p_title)) > 120 THEN
        RAISE EXCEPTION 'VALIDATION_ERROR: Judul tugas harus 1-120 karakter' USING ERRCODE = 'P0003';
    END IF;
    IF p_deadline_at IS NULL OR NOT isfinite(p_deadline_at)
        OR (p_course IS NOT NULL AND char_length(trim(p_course)) > 100) THEN
        RAISE EXCEPTION 'VALIDATION_ERROR: Tenggat atau mata kuliah tidak valid' USING ERRCODE = 'P0003';
    END IF;
    IF p_task_id IS NULL AND p_remaining_minutes = 0 THEN
        RAISE EXCEPTION 'VALIDATION_ERROR: Tugas baru harus memiliki sisa positif' USING ERRCODE = 'P0003';
    END IF;
    IF p_remaining_minutes IS NULL OR p_remaining_minutes < 0 THEN
        RAISE EXCEPTION 'VALIDATION_ERROR: Sisa durasi tidak boleh negatif' USING ERRCODE = 'P0003';
    END IF;

    IF p_task_id IS NULL THEN
        INSERT INTO public.tasks (user_id, title, course, deadline_at, remaining_minutes)
        VALUES (uid, trim(p_title), trim(p_course), p_deadline_at, p_remaining_minutes);
    ELSE
        UPDATE public.tasks
        SET title = trim(p_title),
            course = trim(p_course),
            deadline_at = p_deadline_at,
            remaining_minutes = p_remaining_minutes
        WHERE id = p_task_id AND user_id = uid;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'NOT_FOUND: Tugas tidak ditemukan' USING ERRCODE = 'P0004';
        END IF;
    END IF;

    UPDATE public.planner_state
    SET revision = revision + 1
    WHERE user_id = uid
    RETURNING revision INTO new_rev;

    RETURN new_rev;
END;
$$;

CREATE OR REPLACE FUNCTION public.delete_task(
    p_task_id uuid,
    p_confirm_delete boolean,
    p_expected_revision bigint
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    uid uuid;
    current_rev bigint;
    new_rev bigint;
BEGIN
    uid := auth.uid();
    IF uid IS NULL THEN
        RAISE EXCEPTION 'UNAUTHENTICATED' USING ERRCODE = 'P0001';
    END IF;

    IF p_confirm_delete IS NOT TRUE THEN
        RAISE EXCEPTION 'VALIDATION_ERROR: Penghapusan harus dikonfirmasi' USING ERRCODE = 'P0003';
    END IF;

    INSERT INTO public.planner_state (user_id, revision)
    VALUES (uid, 0)
    ON CONFLICT (user_id) DO NOTHING;

    SELECT revision INTO current_rev
    FROM public.planner_state
    WHERE user_id = uid
    FOR UPDATE;

    IF current_rev IS DISTINCT FROM p_expected_revision THEN
        RAISE EXCEPTION 'STALE_REVISION' USING ERRCODE = 'P0002';
    END IF;

    DELETE FROM public.tasks
    WHERE id = p_task_id AND user_id = uid;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'NOT_FOUND: Tugas tidak ditemukan' USING ERRCODE = 'P0004';
    END IF;

    UPDATE public.planner_state
    SET revision = revision + 1
    WHERE user_id = uid
    RETURNING revision INTO new_rev;

    RETURN new_rev;
END;
$$;

-- ============================================================================
-- 3. CRUD Time Windows
-- ============================================================================
CREATE OR REPLACE FUNCTION public.save_time_window(
    p_id uuid,
    p_weekday smallint,
    p_date date,
    p_start_minute integer,
    p_end_minute integer,
    p_expected_revision bigint
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    uid uuid;
    current_rev bigint;
    new_rev bigint;
BEGIN
    uid := auth.uid();
    IF uid IS NULL THEN
        RAISE EXCEPTION 'UNAUTHENTICATED' USING ERRCODE = 'P0001';
    END IF;

    INSERT INTO public.planner_state (user_id, revision)
    VALUES (uid, 0)
    ON CONFLICT (user_id) DO NOTHING;

    SELECT revision INTO current_rev
    FROM public.planner_state
    WHERE user_id = uid
    FOR UPDATE;

    IF current_rev IS DISTINCT FROM p_expected_revision THEN
        RAISE EXCEPTION 'STALE_REVISION' USING ERRCODE = 'P0002';
    END IF;

    IF p_start_minute IS NULL OR p_end_minute IS NULL
        OR p_start_minute NOT BETWEEN 0 AND 1439
        OR p_end_minute NOT BETWEEN 1 AND 1440
        OR p_end_minute <= p_start_minute
        OR (p_weekday IS NOT NULL AND p_weekday NOT BETWEEN 1 AND 7)
        OR (p_date IS NOT NULL AND NOT isfinite(p_date)) THEN
        RAISE EXCEPTION 'VALIDATION_ERROR: Waktu selesai harus lebih besar dari mulai' USING ERRCODE = 'P0003';
    END IF;

    IF (p_weekday IS NOT NULL AND p_date IS NOT NULL) OR (p_weekday IS NULL AND p_date IS NULL) THEN
        RAISE EXCEPTION 'VALIDATION_ERROR: Harus memilih tepat satu antara weekday atau date' USING ERRCODE = 'P0003';
    END IF;

    IF p_id IS NULL THEN
        INSERT INTO public.time_windows (user_id, weekday, date, start_minute, end_minute)
        VALUES (uid, p_weekday, p_date, p_start_minute, p_end_minute);
    ELSE
        UPDATE public.time_windows
        SET weekday = p_weekday,
            date = p_date,
            start_minute = p_start_minute,
            end_minute = p_end_minute
        WHERE id = p_id AND user_id = uid;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'NOT_FOUND: Waktu luang tidak ditemukan' USING ERRCODE = 'P0004';
        END IF;
    END IF;

    UPDATE public.planner_state
    SET revision = revision + 1
    WHERE user_id = uid
    RETURNING revision INTO new_rev;

    RETURN new_rev;
END;
$$;

CREATE OR REPLACE FUNCTION public.delete_time_window(
    p_id uuid,
    p_expected_revision bigint
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    uid uuid;
    current_rev bigint;
    new_rev bigint;
BEGIN
    uid := auth.uid();
    IF uid IS NULL THEN
        RAISE EXCEPTION 'UNAUTHENTICATED' USING ERRCODE = 'P0001';
    END IF;

    INSERT INTO public.planner_state (user_id, revision)
    VALUES (uid, 0)
    ON CONFLICT (user_id) DO NOTHING;

    SELECT revision INTO current_rev
    FROM public.planner_state
    WHERE user_id = uid
    FOR UPDATE;

    IF current_rev IS DISTINCT FROM p_expected_revision THEN
        RAISE EXCEPTION 'STALE_REVISION' USING ERRCODE = 'P0002';
    END IF;

    DELETE FROM public.time_windows
    WHERE id = p_id AND user_id = uid;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'NOT_FOUND: Waktu luang tidak ditemukan' USING ERRCODE = 'P0004';
    END IF;

    UPDATE public.planner_state
    SET revision = revision + 1
    WHERE user_id = uid
    RETURNING revision INTO new_rev;

    RETURN new_rev;
END;
$$;

-- ============================================================================
-- 4. CRUD Activities
-- ============================================================================
CREATE OR REPLACE FUNCTION public.save_activity(
    p_id uuid,
    p_kind text,
    p_label text,
    p_weekday smallint,
    p_date date,
    p_start_minute integer,
    p_end_minute integer,
    p_expected_revision bigint
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    uid uuid;
    current_rev bigint;
    new_rev bigint;
BEGIN
    uid := auth.uid();
    IF uid IS NULL THEN
        RAISE EXCEPTION 'UNAUTHENTICATED' USING ERRCODE = 'P0001';
    END IF;

    INSERT INTO public.planner_state (user_id, revision)
    VALUES (uid, 0)
    ON CONFLICT (user_id) DO NOTHING;

    SELECT revision INTO current_rev
    FROM public.planner_state
    WHERE user_id = uid
    FOR UPDATE;

    IF current_rev IS DISTINCT FROM p_expected_revision THEN
        RAISE EXCEPTION 'STALE_REVISION' USING ERRCODE = 'P0002';
    END IF;

    IF p_kind IS NULL OR p_kind NOT IN ('routine', 'event', 'blocked')
        OR p_label IS NULL OR char_length(trim(p_label)) NOT BETWEEN 1 AND 120 THEN
        RAISE EXCEPTION 'VALIDATION_ERROR: Jenis kegiatan tidak valid' USING ERRCODE = 'P0003';
    END IF;

    IF p_start_minute IS NULL OR p_end_minute IS NULL
        OR p_start_minute NOT BETWEEN 0 AND 1439
        OR p_end_minute NOT BETWEEN 1 AND 1440
        OR p_end_minute <= p_start_minute
        OR (p_weekday IS NOT NULL AND p_weekday NOT BETWEEN 1 AND 7)
        OR (p_date IS NOT NULL AND NOT isfinite(p_date)) THEN
        RAISE EXCEPTION 'VALIDATION_ERROR: Waktu selesai harus lebih besar dari mulai' USING ERRCODE = 'P0003';
    END IF;

    IF p_kind = 'routine' AND (p_weekday IS NULL OR p_date IS NOT NULL) THEN
        RAISE EXCEPTION 'VALIDATION_ERROR: Rutinitas harus memakai weekday' USING ERRCODE = 'P0003';
    END IF;

    IF p_kind IN ('event', 'blocked') AND (p_date IS NULL OR p_weekday IS NOT NULL) THEN
        RAISE EXCEPTION 'VALIDATION_ERROR: Acara/penutupan harus memakai tanggal spesifik' USING ERRCODE = 'P0003';
    END IF;

    IF p_id IS NULL THEN
        INSERT INTO public.activities (user_id, kind, label, weekday, date, start_minute, end_minute)
        VALUES (uid, p_kind, trim(p_label), p_weekday, p_date, p_start_minute, p_end_minute);
    ELSE
        UPDATE public.activities
        SET kind = p_kind,
            label = trim(p_label),
            weekday = p_weekday,
            date = p_date,
            start_minute = p_start_minute,
            end_minute = p_end_minute
        WHERE id = p_id AND user_id = uid;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'NOT_FOUND: Kegiatan tidak ditemukan' USING ERRCODE = 'P0004';
        END IF;
    END IF;

    UPDATE public.planner_state
    SET revision = revision + 1
    WHERE user_id = uid
    RETURNING revision INTO new_rev;

    RETURN new_rev;
END;
$$;

CREATE OR REPLACE FUNCTION public.delete_activity(
    p_id uuid,
    p_expected_revision bigint
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    uid uuid;
    current_rev bigint;
    new_rev bigint;
BEGIN
    uid := auth.uid();
    IF uid IS NULL THEN
        RAISE EXCEPTION 'UNAUTHENTICATED' USING ERRCODE = 'P0001';
    END IF;

    INSERT INTO public.planner_state (user_id, revision)
    VALUES (uid, 0)
    ON CONFLICT (user_id) DO NOTHING;

    SELECT revision INTO current_rev
    FROM public.planner_state
    WHERE user_id = uid
    FOR UPDATE;

    IF current_rev IS DISTINCT FROM p_expected_revision THEN
        RAISE EXCEPTION 'STALE_REVISION' USING ERRCODE = 'P0002';
    END IF;

    DELETE FROM public.activities
    WHERE id = p_id AND user_id = uid;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'NOT_FOUND: Kegiatan tidak ditemukan' USING ERRCODE = 'P0004';
    END IF;

    UPDATE public.planner_state
    SET revision = revision + 1
    WHERE user_id = uid
    RETURNING revision INTO new_rev;

    RETURN new_rev;
END;
$$;

-- ============================================================================
-- 5. Pencatatan Progres Sesi (Atomic Progress Closer)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.record_progress(
    p_session_id uuid,
    p_status text,
    p_remaining_after integer,
    p_expected_revision bigint
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    uid uuid;
    current_rev bigint;
    new_rev bigint;
    session_rec record;
BEGIN
    uid := auth.uid();
    IF uid IS NULL THEN
        RAISE EXCEPTION 'UNAUTHENTICATED' USING ERRCODE = 'P0001';
    END IF;

    IF p_status IS NULL OR p_status NOT IN ('completed', 'missed') THEN
        RAISE EXCEPTION 'VALIDATION_ERROR: Status progres hanya completed atau missed' USING ERRCODE = 'P0003';
    END IF;

    IF p_status = 'missed' AND p_remaining_after IS NOT NULL THEN
        RAISE EXCEPTION 'VALIDATION_ERROR: Missed harus memakai sisa null' USING ERRCODE = 'P0003';
    END IF;

    IF p_status = 'completed' AND (p_remaining_after IS NULL OR p_remaining_after < 0) THEN
        RAISE EXCEPTION 'VALIDATION_ERROR: Sisa menit harus diisi dan >= 0 untuk completed' USING ERRCODE = 'P0003';
    END IF;

    INSERT INTO public.planner_state (user_id, revision)
    VALUES (uid, 0)
    ON CONFLICT (user_id) DO NOTHING;

    SELECT revision INTO current_rev
    FROM public.planner_state
    WHERE user_id = uid
    FOR UPDATE;

    IF current_rev IS DISTINCT FROM p_expected_revision THEN
        RAISE EXCEPTION 'STALE_REVISION' USING ERRCODE = 'P0002';
    END IF;

    SELECT * INTO session_rec
    FROM public.sessions
    WHERE id = p_session_id AND user_id = uid
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'NOT_FOUND: Sesi tidak ditemukan' USING ERRCODE = 'P0004';
    END IF;

    IF session_rec.status <> 'planned' THEN
        RAISE EXCEPTION 'SESSION_ALREADY_CLOSED: Sesi sudah ditutup sebelumnya' USING ERRCODE = 'P0005';
    END IF;

    IF session_rec.starts_at > now() THEN
        RAISE EXCEPTION 'VALIDATION_ERROR: Sesi masa depan belum dapat ditutup' USING ERRCODE = 'P0003';
    END IF;

    -- Update status sesi
    UPDATE public.sessions
    SET status = p_status,
        remaining_after = CASE WHEN p_status = 'completed' THEN p_remaining_after ELSE NULL END,
        closed_at = now()
    WHERE id = p_session_id AND user_id = uid;

    -- Perbarui sisa waktu tugas jika status completed
    IF p_status = 'completed' THEN
        UPDATE public.tasks
        SET remaining_minutes = p_remaining_after
        WHERE id = session_rec.task_id AND user_id = uid;
    END IF;

    UPDATE public.planner_state
    SET revision = revision + 1
    WHERE user_id = uid
    RETURNING revision INTO new_rev;

    RETURN new_rev;
END;
$$;

-- ============================================================================
-- 6. Konfirmasi Jadwal (Confirm Schedule & Cancel Future Planned)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.confirm_schedule(
    input_revision bigint,
    window_start timestamptz,
    window_end timestamptz,
    sessions jsonb
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    uid uuid;
    current_rev bigint;
    new_rev bigint;
    server_now timestamptz;
    today date;
    minute_now timestamptz;
    available tstzmultirange;
    busy tstzmultirange;
    item jsonb;
    t_id uuid;
    s_start timestamptz;
    s_end timestamptz;
    t_deadline timestamptz;
    t_rem_minutes integer;
BEGIN
    uid := auth.uid();
    IF uid IS NULL THEN
        RAISE EXCEPTION 'UNAUTHENTICATED' USING ERRCODE = 'P0001';
    END IF;

    INSERT INTO public.planner_state (user_id, revision)
    VALUES (uid, 0) ON CONFLICT (user_id) DO NOTHING;
    SELECT revision INTO current_rev FROM public.planner_state
    WHERE user_id = uid FOR UPDATE;
    IF current_rev IS DISTINCT FROM input_revision THEN
        RAISE EXCEPTION 'STALE_REVISION' USING ERRCODE = 'P0002';
    END IF;

    -- Read the server clock after waiting for the per-owner lock.
    server_now := clock_timestamp();
    today := (server_now AT TIME ZONE 'Asia/Jakarta')::date;
    minute_now := date_trunc('minute', server_now);
    IF minute_now < server_now THEN
        minute_now := minute_now + interval '1 minute';
    END IF;
    -- Preview start may precede confirmation, but must still name today's window.
    IF window_start IS NULL OR window_end IS NULL
        OR NOT isfinite(window_start) OR NOT isfinite(window_end)
        OR date_trunc('minute', window_start) <> window_start
        OR window_start < (today::timestamp AT TIME ZONE 'Asia/Jakarta')
        OR window_start > minute_now
        OR window_end <> ((today + 14)::timestamp AT TIME ZONE 'Asia/Jakarta')
        OR window_end <= window_start THEN
        RAISE EXCEPTION 'VALIDATION_ERROR: Batas jendela tidak valid' USING ERRCODE = 'P0003';
    END IF;
    IF sessions IS NULL OR jsonb_typeof(sessions) <> 'array' THEN
        RAISE EXCEPTION 'VALIDATION_ERROR: Kandidat harus berupa array' USING ERRCODE = 'P0003';
    END IF;
    IF EXISTS (SELECT 1 FROM public.sessions
        WHERE user_id = uid AND status = 'planned' AND starts_at <= server_now) THEN
        RAISE EXCEPTION 'VALIDATION_ERROR: Terdapat sesi yang sudah mulai tetapi progresnya belum ditutup' USING ERRCODE = 'P0003';
    END IF;

    -- Multiranges merge overlapping/adjacent manual windows before subtracting busy time.
    SELECT COALESCE(range_agg(tstzrange(
        (d.day::timestamp + w.start_minute * interval '1 minute') AT TIME ZONE 'Asia/Jakarta',
        (d.day::timestamp + w.end_minute * interval '1 minute') AT TIME ZONE 'Asia/Jakarta', '[)'
    )), '{}'::tstzmultirange) INTO available
    FROM (SELECT today + n AS day FROM generate_series(0,13) n) d
    JOIN public.time_windows w ON w.user_id = uid
        AND (w.date = d.day OR w.weekday = extract(isodow FROM d.day));

    SELECT COALESCE(range_agg(r), '{}'::tstzmultirange) INTO busy FROM (
        SELECT tstzrange(
            (d.day::timestamp + a.start_minute * interval '1 minute') AT TIME ZONE 'Asia/Jakarta',
            (d.day::timestamp + a.end_minute * interval '1 minute') AT TIME ZONE 'Asia/Jakarta', '[)'
        ) AS r
        FROM (SELECT today + n AS day FROM generate_series(0,13) n) d
        JOIN public.activities a ON a.user_id = uid
            AND (a.date = d.day OR a.weekday = extract(isodow FROM d.day))
        UNION ALL
        SELECT tstzrange(s.starts_at,s.ends_at,'[)') FROM public.sessions s
        WHERE s.user_id = uid AND s.status = 'completed'
            AND s.starts_at < window_end AND s.ends_at > window_start
    ) blocked;
    available := available - busy;

    -- Any later exception rolls back cancellation, inserts, and the revision together.
    UPDATE public.sessions SET status = 'cancelled'
    WHERE user_id = uid AND status = 'planned' AND starts_at > server_now;

    FOR item IN SELECT * FROM jsonb_array_elements(sessions) LOOP
        IF jsonb_typeof(item) <> 'object' OR item->>'task_id' IS NULL
            OR item->>'starts_at' IS NULL OR item->>'ends_at' IS NULL
            OR jsonb_typeof(item->'task_id') <> 'string'
            OR jsonb_typeof(item->'starts_at') <> 'string'
            OR jsonb_typeof(item->'ends_at') <> 'string' THEN
            RAISE EXCEPTION 'VALIDATION_ERROR: Kandidat tidak lengkap' USING ERRCODE = 'P0003';
        END IF;
        BEGIN
            t_id := (item->>'task_id')::uuid;
            s_start := (item->>'starts_at')::timestamptz;
            s_end := (item->>'ends_at')::timestamptz;
        EXCEPTION WHEN invalid_text_representation OR invalid_datetime_format OR datetime_field_overflow THEN
            RAISE EXCEPTION 'VALIDATION_ERROR: Format kandidat tidak valid' USING ERRCODE = 'P0003';
        END;
        IF NOT isfinite(s_start) OR NOT isfinite(s_end)
            OR s_end <= s_start OR s_start < minute_now
            OR s_start < window_start OR s_end > window_end
            OR date_trunc('minute',s_start) <> s_start
            OR date_trunc('minute',s_end) <> s_end THEN
            RAISE EXCEPTION 'VALIDATION_ERROR: Rentang sesi tidak valid' USING ERRCODE = 'P0003';
        END IF;
        SELECT deadline_at, remaining_minutes INTO t_deadline, t_rem_minutes
        FROM public.tasks WHERE id = t_id AND user_id = uid;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'NOT_FOUND: Tugas kandidat tidak ditemukan atau bukan milik akun ini' USING ERRCODE = 'P0004';
        END IF;
        IF s_end > t_deadline OR t_rem_minutes = 0
            OR NOT (tstzrange(s_start,s_end,'[)') <@ available) THEN
            RAISE EXCEPTION 'VALIDATION_ERROR: Sesi melampaui tenggat, sisa, atau waktu tersedia' USING ERRCODE = 'P0003';
        END IF;
        IF EXISTS (SELECT 1 FROM public.sessions s WHERE s.user_id = uid
            AND s.status = 'planned' AND s.starts_at < s_end AND s.ends_at > s_start) THEN
            RAISE EXCEPTION 'VALIDATION_ERROR: Sesi saling overlap' USING ERRCODE = 'P0003';
        END IF;
        IF COALESCE((SELECT sum(extract(epoch FROM (s.ends_at-s.starts_at))/60)
            FROM public.sessions s WHERE s.user_id = uid AND s.task_id = t_id
                AND s.status = 'planned'),0) + extract(epoch FROM (s_end-s_start))/60 > t_rem_minutes THEN
            RAISE EXCEPTION 'VALIDATION_ERROR: Alokasi melebihi sisa tugas' USING ERRCODE = 'P0003';
        END IF;
        INSERT INTO public.sessions(user_id,task_id,starts_at,ends_at,status)
        VALUES (uid,t_id,s_start,s_end,'planned');
    END LOOP;
    UPDATE public.planner_state SET revision = revision + 1 WHERE user_id = uid
    RETURNING revision INTO new_rev;
    RETURN new_rev;
END;
$$;

-- Berikan izin eksekusi RPC hanya ke authenticated
REVOKE EXECUTE ON FUNCTION
 public.get_planner_snapshot(),
 public.save_task(uuid, text, text, timestamptz, integer, bigint),
 public.delete_task(uuid, boolean, bigint),
 public.save_time_window(uuid, smallint, date, integer, integer, bigint),
 public.delete_time_window(uuid, bigint),
 public.save_activity(uuid, text, text, smallint, date, integer, integer, bigint),
 public.delete_activity(uuid, bigint),
 public.record_progress(uuid, text, integer, bigint),
 public.confirm_schedule(bigint, timestamptz, timestamptz, jsonb)
 FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_planner_snapshot() TO authenticated;
GRANT EXECUTE ON FUNCTION public.save_task(uuid, text, text, timestamptz, integer, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_task(uuid, boolean, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.save_time_window(uuid, smallint, date, integer, integer, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_time_window(uuid, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.save_activity(uuid, text, text, smallint, date, integer, integer, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_activity(uuid, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_progress(uuid, text, integer, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.confirm_schedule(bigint, timestamptz, timestamptz, jsonb) TO authenticated;
