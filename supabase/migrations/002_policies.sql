-- 002_policies.sql
-- Kebijakan Row Level Security (RLS) dan Izin Akses Tabel
-- Berdasarkan PRD_WaktuTugas_Ahmad_Turmudi_60324069.md Bagian 7.2 & 9.1

-- Aktifkan RLS di seluruh tabel
ALTER TABLE public.planner_state ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.time_windows ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sessions ENABLE ROW LEVEL SECURITY;

-- 1. Kebijakan SELECT (Hanya baris milik sendiri yang dapat dibaca)
CREATE POLICY "Users can view their own planner_state"
    ON public.planner_state
    FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Users can view their own tasks"
    ON public.tasks
    FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Users can view their own time_windows"
    ON public.time_windows
    FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Users can view their own activities"
    ON public.activities
    FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Users can view their own sessions"
    ON public.sessions
    FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

-- 2. Batasi manipulasi data langsung (Direct Writes) via REST API
-- Sesuai PRD Bagian 7.2: Semua mutasi wajib melalui RPC transaksional ber-revisi.
-- Tulis langsung dibatasi agar perubahan tidak melewati mekanisme lock dan validasi revisi.
REVOKE ALL ON public.planner_state FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.tasks FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.time_windows FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.activities FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.sessions FROM PUBLIC, anon, authenticated;

-- Berikan hak baca (SELECT) kepada role authenticated
GRANT SELECT ON public.planner_state TO authenticated;
GRANT SELECT ON public.tasks TO authenticated;
GRANT SELECT ON public.time_windows TO authenticated;
GRANT SELECT ON public.activities TO authenticated;
GRANT SELECT ON public.sessions TO authenticated;
