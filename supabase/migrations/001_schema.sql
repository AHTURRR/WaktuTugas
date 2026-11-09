-- 001_schema.sql
-- Skema Database WaktuTugas (5 Tabel Inti)
-- Berdasarkan PRD_WaktuTugas_Ahmad_Turmudi_60324069.md Bagian 6

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 1. Tabel planner_state (Revisi atomik per pengguna)
CREATE TABLE IF NOT EXISTS public.planner_state (
    user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    revision bigint NOT NULL DEFAULT 0 CHECK (revision >= 0)
);

-- 2. Tabel tasks (Daftar tugas kuliah pribadi)
CREATE TABLE IF NOT EXISTS public.tasks (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title text NOT NULL,
    course text,
    deadline_at timestamptz NOT NULL,
    remaining_minutes integer NOT NULL CHECK (remaining_minutes >= 0),
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT tasks_title_length CHECK (char_length(trim(title)) BETWEEN 1 AND 120),
    CONSTRAINT tasks_course_length CHECK (course IS NULL OR char_length(trim(course)) <= 100),
    CONSTRAINT tasks_user_task_unique UNIQUE (id, user_id)
);

-- 3. Tabel time_windows (Rentang waktu luang yang diizinkan)
CREATE TABLE IF NOT EXISTS public.time_windows (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    weekday smallint CHECK (weekday BETWEEN 1 AND 7),
    date date,
    start_minute integer NOT NULL CHECK (start_minute BETWEEN 0 AND 1439),
    end_minute integer NOT NULL CHECK (end_minute BETWEEN 1 AND 1440),
    CONSTRAINT time_windows_order CHECK (end_minute > start_minute),
    CONSTRAINT time_windows_target CHECK (
        (weekday IS NOT NULL AND date IS NULL) OR
        (weekday IS NULL AND date IS NOT NULL)
    ),
    CONSTRAINT time_windows_user_unique UNIQUE (id, user_id)
);

-- 4. Tabel activities (Kegiatan rutin, acara, dan penutupan waktu)
CREATE TABLE IF NOT EXISTS public.activities (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    kind text NOT NULL CHECK (kind IN ('routine', 'event', 'blocked')),
    label text NOT NULL,
    weekday smallint CHECK (weekday BETWEEN 1 AND 7),
    date date,
    start_minute integer NOT NULL CHECK (start_minute BETWEEN 0 AND 1439),
    end_minute integer NOT NULL CHECK (end_minute BETWEEN 1 AND 1440),
    CONSTRAINT activities_label_length CHECK (char_length(trim(label)) BETWEEN 1 AND 120),
    CONSTRAINT activities_order CHECK (end_minute > start_minute),
    CONSTRAINT activities_kind_target CHECK (
        (kind = 'routine' AND weekday IS NOT NULL AND date IS NULL) OR
        (kind IN ('event', 'blocked') AND date IS NOT NULL AND weekday IS NULL)
    ),
    CONSTRAINT activities_user_unique UNIQUE (id, user_id)
);

-- 5. Tabel sessions (Sesi belajar terencana dan riwayat pengerjaan)
CREATE TABLE IF NOT EXISTS public.sessions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    task_id uuid NOT NULL,
    starts_at timestamptz NOT NULL,
    ends_at timestamptz NOT NULL,
    status text NOT NULL CHECK (status IN ('planned', 'completed', 'missed', 'cancelled')),
    remaining_after integer CHECK (remaining_after IS NULL OR remaining_after >= 0),
    closed_at timestamptz,
    CONSTRAINT sessions_interval CHECK (ends_at > starts_at),
    CONSTRAINT sessions_whole_minutes CHECK (
        isfinite(starts_at) AND isfinite(ends_at)
        AND date_trunc('minute', starts_at) = starts_at
        AND date_trunc('minute', ends_at) = ends_at
    ),
    CONSTRAINT sessions_task_owner_fkey FOREIGN KEY (task_id, user_id) REFERENCES public.tasks(id, user_id) ON DELETE CASCADE,
    CONSTRAINT sessions_user_unique UNIQUE (id, user_id)
);

-- Indeks untuk efisiensi kueri dan filter RLS
CREATE INDEX IF NOT EXISTS idx_tasks_user_deadline ON public.tasks(user_id, deadline_at);
CREATE INDEX IF NOT EXISTS idx_time_windows_user ON public.time_windows(user_id);
CREATE INDEX IF NOT EXISTS idx_activities_user ON public.activities(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_user_starts ON public.sessions(user_id, starts_at);
CREATE INDEX IF NOT EXISTS idx_sessions_user_status ON public.sessions(user_id, status);
