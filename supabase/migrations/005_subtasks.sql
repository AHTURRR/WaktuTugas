-- 005_subtasks.sql
-- Daftar subtugas satu tingkat yang terikat ke tugas induk dan terisolasi per akun

-- 1. Tabel subtasks
CREATE TABLE IF NOT EXISTS public.subtasks (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    task_id uuid NOT NULL,
    title text NOT NULL,
    is_completed boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT subtasks_title_length CHECK (char_length(trim(title)) BETWEEN 1 AND 120),
    CONSTRAINT subtasks_task_owner_fkey FOREIGN KEY (task_id, user_id)
        REFERENCES public.tasks(id, user_id) ON DELETE CASCADE,
    CONSTRAINT subtasks_user_unique UNIQUE (id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_subtasks_user_task
    ON public.subtasks(user_id, task_id, created_at, id);

-- 2. Kebijakan RLS dan pembatasan direct writes
ALTER TABLE public.subtasks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own subtasks" ON public.subtasks;
CREATE POLICY "Users can view their own subtasks"
    ON public.subtasks
    FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

REVOKE ALL ON public.subtasks FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.subtasks TO authenticated;

-- 3. Perbarui get_planner_snapshot agar menyertakan subtasks per tugas
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

    INSERT INTO public.planner_state (user_id, revision)
    VALUES (uid, 0)
    ON CONFLICT (user_id) DO NOTHING;

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
                    'created_at', t.created_at,
                    'subtasks', COALESCE((
                        SELECT jsonb_agg(
                            jsonb_build_object(
                                'id', st.id,
                                'task_id', st.task_id,
                                'title', st.title,
                                'is_completed', st.is_completed
                            ) ORDER BY st.created_at ASC, st.id ASC
                        )
                        FROM public.subtasks st
                        WHERE st.user_id = uid AND st.task_id = t.id
                    ), '[]'::jsonb)
                ) ORDER BY t.created_at ASC, t.id ASC
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
                ) ORDER BY w.weekday ASC NULLS LAST, w.date ASC NULLS LAST, w.start_minute ASC, w.id ASC
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
                ) ORDER BY a.weekday ASC NULLS LAST, a.date ASC NULLS LAST, a.start_minute ASC, a.id ASC
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
                ) ORDER BY s.starts_at ASC, s.id ASC
            ) FROM public.sessions s WHERE s.user_id = uid
        ), '[]'::jsonb)
    ) INTO res;

    RETURN res;
END;
$$;

-- 4. RPC save_subtask & delete_subtask (ber-revisi dan terisolasi per akun)
CREATE OR REPLACE FUNCTION public.save_subtask(
    p_subtask_id uuid,
    p_task_id uuid,
    p_title text,
    p_is_completed boolean,
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

    IF p_title IS NULL OR char_length(trim(p_title)) < 1 OR char_length(trim(p_title)) > 120 THEN
        RAISE EXCEPTION 'VALIDATION_ERROR: Nama subtugas harus 1-120 karakter' USING ERRCODE = 'P0003';
    END IF;

    IF p_is_completed IS NULL THEN
        RAISE EXCEPTION 'VALIDATION_ERROR: Status selesai subtugas wajib diisi' USING ERRCODE = 'P0003';
    END IF;

    -- Pastikan tugas induk milik akun ini
    IF NOT EXISTS (SELECT 1 FROM public.tasks WHERE id = p_task_id AND user_id = uid) THEN
        RAISE EXCEPTION 'NOT_FOUND: Tugas induk tidak ditemukan' USING ERRCODE = 'P0004';
    END IF;

    IF p_subtask_id IS NULL THEN
        INSERT INTO public.subtasks (user_id, task_id, title, is_completed)
        VALUES (uid, p_task_id, trim(p_title), p_is_completed);
    ELSE
        UPDATE public.subtasks
        SET title = trim(p_title),
            is_completed = p_is_completed
        WHERE id = p_subtask_id AND task_id = p_task_id AND user_id = uid;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'NOT_FOUND: Subtugas tidak ditemukan' USING ERRCODE = 'P0004';
        END IF;
    END IF;

    UPDATE public.planner_state
    SET revision = revision + 1
    WHERE user_id = uid
    RETURNING revision INTO new_rev;

    RETURN new_rev;
END;
$$;

CREATE OR REPLACE FUNCTION public.delete_subtask(
    p_subtask_id uuid,
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

    DELETE FROM public.subtasks
    WHERE id = p_subtask_id AND user_id = uid;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'NOT_FOUND: Subtugas tidak ditemukan' USING ERRCODE = 'P0004';
    END IF;

    UPDATE public.planner_state
    SET revision = revision + 1
    WHERE user_id = uid
    RETURNING revision INTO new_rev;

    RETURN new_rev;
END;
$$;

REVOKE ALL ON FUNCTION public.save_subtask(uuid, uuid, text, boolean, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.save_subtask(uuid, uuid, text, boolean, bigint) TO authenticated;
REVOKE ALL ON FUNCTION public.delete_subtask(uuid, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.delete_subtask(uuid, bigint) TO authenticated;
