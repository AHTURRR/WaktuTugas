-- Disposable local fixtures: all changes roll back.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path = public, extensions, pg_temp;
SELECT no_plan();
INSERT INTO auth.users (id, email) VALUES
 ('11111111-1111-1111-1111-111111111111', 'sql-a@example.invalid'),
 ('22222222-2222-2222-2222-222222222222', 'sql-b@example.invalid');
INSERT INTO public.planner_state(user_id) VALUES
 ('11111111-1111-1111-1111-111111111111'),('22222222-2222-2222-2222-222222222222');
INSERT INTO public.tasks(id, user_id, title, deadline_at, remaining_minutes) VALUES
 ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'A', now()+interval '20 days', 120),
 ('bbbbbbbb-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 'B', now()+interval '20 days', 120);
INSERT INTO public.time_windows(id, user_id, weekday, start_minute, end_minute) VALUES
 ('aaaaaaaa-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 1, 0, 1440),
 ('bbbbbbbb-0000-0000-0000-000000000002', '22222222-2222-2222-2222-222222222222', 1, 0, 1440);
INSERT INTO public.activities(id, user_id, kind, label, weekday, start_minute, end_minute) VALUES
 ('aaaaaaaa-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111', 'routine', 'A', 1, 60, 120),
 ('bbbbbbbb-0000-0000-0000-000000000003', '22222222-2222-2222-2222-222222222222', 'routine', 'B', 1, 60, 120);
INSERT INTO public.sessions(id, user_id, task_id, starts_at, ends_at, status) VALUES
 ('aaaaaaaa-0000-0000-0000-000000000004', '11111111-1111-1111-1111-111111111111', 'aaaaaaaa-0000-0000-0000-000000000001', date_trunc('minute',now())-interval '2 hours', date_trunc('minute',now())-interval '1 hour', 'planned'),
 ('bbbbbbbb-0000-0000-0000-000000000004', '22222222-2222-2222-2222-222222222222', 'bbbbbbbb-0000-0000-0000-000000000001', date_trunc('minute',now())-interval '2 hours', date_trunc('minute',now())-interval '1 hour', 'planned');
SELECT throws_ok($$INSERT INTO public.sessions(user_id,task_id,starts_at,ends_at,status)
 VALUES ('22222222-2222-2222-2222-222222222222','aaaaaaaa-0000-0000-0000-000000000001',date_trunc('minute',now()),date_trunc('minute',now())+interval '1 minute','planned')$$,
 '23503', NULL, 'session/task owner mismatch rejected by FK');
SELECT ok(c.relrowsecurity, c.relname || ' has RLS') FROM pg_class c
 JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname='public' AND c.relname IN ('planner_state','tasks','time_windows','activities','sessions');
SELECT ok(NOT has_table_privilege(r, 'public.' || t, p), r || ' cannot ' || p || ' ' || t)
 FROM unnest(ARRAY['anon','authenticated']) r
 CROSS JOIN unnest(ARRAY['planner_state','tasks','time_windows','activities','sessions']) t
 CROSS JOIN unnest(ARRAY['INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER']) p;
SELECT ok(NOT has_function_privilege('anon',p.oid,'EXECUTE'), p.proname || ' denies anon')
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.prosecdef;
SELECT ok(p.proconfig @> ARRAY['search_path=""'], p.proname || ' has empty search_path')
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.prosecdef;
SELECT ok(NOT ('user_id'=ANY(p.proargnames)), p.proname || ' takes no client owner')
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.prosecdef AND p.pronargs>0;
SET LOCAL ROLE anon;
SELECT throws_ok('SELECT public.get_planner_snapshot()', '42501', NULL, 'actual anon role cannot execute snapshot');
SELECT throws_ok('SELECT * FROM public.' || t, '42501', NULL, 'anon cannot read ' || t)
 FROM unnest(ARRAY['planner_state','tasks','time_windows','activities','sessions']) t;
RESET ROLE;
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{}';
SELECT throws_ok('SELECT public.get_planner_snapshot()', 'P0001', 'UNAUTHENTICATED', 'missing subject rejected');
SET LOCAL "request.jwt.claims" = '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';
SELECT is((SELECT count(*) FROM public.planner_state), 1::bigint, 'B sees only own state');
SELECT is((SELECT count(*) FROM public.tasks), 1::bigint, 'B sees only own tasks');
SELECT is((SELECT count(*) FROM public.time_windows), 1::bigint, 'B sees only own windows');
SELECT is((SELECT count(*) FROM public.activities), 1::bigint, 'B sees only own activities');
SELECT is((SELECT count(*) FROM public.sessions), 1::bigint, 'B sees only own sessions');
SELECT is(public.get_planner_snapshot()->'tasks'->0->>'id', 'bbbbbbbb-0000-0000-0000-000000000001', 'snapshot contains B task');
SELECT is(public.get_planner_snapshot()->'sessions'->0->>'id', 'bbbbbbbb-0000-0000-0000-000000000004', 'snapshot contains B session');
SELECT is(public.get_planner_snapshot()->'time_windows'->0->>'id', 'bbbbbbbb-0000-0000-0000-000000000002', 'snapshot contains B window');
SELECT is(public.get_planner_snapshot()->'activities'->0->>'id', 'bbbbbbbb-0000-0000-0000-000000000003', 'snapshot contains B activity');
-- Known foreign IDs; an RLS-filtered lookup would only test NULL.
SELECT throws_ok(q, 'P0004', NULL, label) FROM (VALUES
 ($$SELECT public.save_task('aaaaaaaa-0000-0000-0000-000000000001','attack',NULL,now()+interval '1 day',10,0)$$, 'foreign task update'),
 ($$SELECT public.delete_task('aaaaaaaa-0000-0000-0000-000000000001',true,0)$$, 'foreign task delete'),
 ($$SELECT public.save_time_window('aaaaaaaa-0000-0000-0000-000000000002',1::smallint,NULL,0,60,0)$$, 'foreign window update'),
 ($$SELECT public.delete_time_window('aaaaaaaa-0000-0000-0000-000000000002',0)$$, 'foreign window delete'),
 ($$SELECT public.save_activity('aaaaaaaa-0000-0000-0000-000000000003','routine','attack',1::smallint,NULL,0,60,0)$$, 'foreign activity update'),
 ($$SELECT public.delete_activity('aaaaaaaa-0000-0000-0000-000000000003',0)$$, 'foreign activity delete'),
 ($$SELECT public.record_progress('aaaaaaaa-0000-0000-0000-000000000004','completed',0,0)$$, 'foreign progress close')
) cases(q,label);
SELECT is((public.get_planner_snapshot()->>'revision')::bigint,0::bigint,'foreign mutations leave B revision unchanged');
SELECT throws_ok($$INSERT INTO public.tasks(user_id,title,deadline_at,remaining_minutes)
 VALUES ('11111111-1111-1111-1111-111111111111','spoof',now(),1)$$,'42501',NULL,'direct owner spoof rejected');
SET LOCAL "request.jwt.claims" = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';
SELECT is(public.get_planner_snapshot()->'tasks'->0->>'title','A','A task unchanged');
SELECT is(public.get_planner_snapshot()->'sessions'->0->>'status','planned','A progress unchanged');
SELECT is((public.get_planner_snapshot()->>'revision')::bigint,0::bigint,'A revision unchanged');
SELECT * FROM finish();
ROLLBACK;
