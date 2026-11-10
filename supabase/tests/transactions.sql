-- AC02, AC11-16, AC18. Run on a disposable local database, never production.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path = public, extensions, pg_temp;
SELECT no_plan();
CREATE TEMP TABLE context AS SELECT
 ((now() AT TIME ZONE 'Asia/Jakarta')::date+1) AS day,
 date_trunc('minute',now())+interval '1 minute' AS ws,
 (((now() AT TIME ZONE 'Asia/Jakarta')::date+14)::timestamp AT TIME ZONE 'Asia/Jakarta') AS we;
GRANT SELECT ON context TO authenticated;
CREATE FUNCTION pg_temp.rev() RETURNS bigint LANGUAGE sql AS
 $$SELECT (public.get_planner_snapshot()->>'revision')::bigint$$;
CREATE FUNCTION pg_temp.candidate(a integer, b integer,
 task uuid DEFAULT 'cccccccc-0000-0000-0000-000000000001') RETURNS jsonb LANGUAGE sql AS $$
 SELECT jsonb_build_object('task_id',task,
 'starts_at',(day::timestamp+a*interval '1 minute') AT TIME ZONE 'Asia/Jakarta',
 'ends_at',(day::timestamp+b*interval '1 minute') AT TIME ZONE 'Asia/Jakarta') FROM pg_temp.context$$;
CREATE FUNCTION pg_temp.confirm(items jsonb, rev bigint DEFAULT 0) RETURNS bigint LANGUAGE sql AS
 $$SELECT public.confirm_schedule(rev,ws,we,items) FROM pg_temp.context$$;
-- An exception alone is insufficient: every rejected call must preserve ALL data.
CREATE FUNCTION pg_temp.reject(q text, code text, label text) RETURNS SETOF text LANGUAGE plpgsql AS $$
DECLARE before_state jsonb;
BEGIN
 before_state := public.get_planner_snapshot();
 RETURN NEXT throws_ok(q,code,NULL,label);
 RETURN NEXT is(public.get_planner_snapshot(),before_state,label || ': entire snapshot unchanged');
END$$;
INSERT INTO auth.users(id,email) VALUES
 ('33333333-3333-3333-3333-333333333333','sql-c@example.invalid'),
 ('44444444-4444-4444-4444-444444444444','sql-d@example.invalid'),
 ('55555555-5555-5555-5555-555555555555','sql-e@example.invalid'),
 ('66666666-6666-6666-6666-666666666666','sql-f@example.invalid');
-- First writes must initialize and lock revision zero without requiring a snapshot.
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"44444444-4444-4444-4444-444444444444","role":"authenticated"}';
SELECT is(public.save_time_window(NULL,1::smallint,NULL,0,60,0),1::bigint,'first window write initializes state');
SET LOCAL "request.jwt.claims" = '{"sub":"55555555-5555-5555-5555-555555555555","role":"authenticated"}';
SELECT is(public.save_activity(NULL,'routine','first',1::smallint,NULL,0,60,0),1::bigint,'first activity write initializes state');
SELECT is(public.save_activity(NULL,'event','',NULL,(SELECT day FROM pg_temp.context),60,120,1),2::bigint,'empty optional activity label accepted');
SET LOCAL "request.jwt.claims" = '{"sub":"66666666-6666-6666-6666-666666666666","role":"authenticated"}';
SELECT throws_ok(q,'P0002',NULL,label) FROM (VALUES
 ($$SELECT public.save_task(NULL,'first',NULL,now(),10,1)$$,'fresh task wrong revision'),
 ($$SELECT public.delete_task(gen_random_uuid(),true,1)$$,'fresh task delete wrong revision'),
 ($$SELECT public.save_time_window(NULL,1::smallint,NULL,0,60,1)$$,'fresh window wrong revision'),
 ($$SELECT public.delete_time_window(gen_random_uuid(),1)$$,'fresh window delete wrong revision'),
 ($$SELECT public.save_activity(NULL,'routine','x',1::smallint,NULL,0,60,1)$$,'fresh activity wrong revision'),
 ($$SELECT public.delete_activity(gen_random_uuid(),1)$$,'fresh activity delete wrong revision'),
 ($$SELECT public.record_progress(gen_random_uuid(),'completed',10,1)$$,'fresh progress wrong revision'),
 ($$SELECT pg_temp.confirm('[]',1)$$,'fresh confirm wrong revision')
) cases(q,label);
SELECT is(public.save_task(NULL,'first',NULL,now(),10,0),1::bigint,'first task write initializes revision zero');
RESET ROLE;
INSERT INTO public.planner_state(user_id) VALUES ('33333333-3333-3333-3333-333333333333');
INSERT INTO public.tasks(id,user_id,title,deadline_at,remaining_minutes) VALUES
 ('cccccccc-0000-0000-0000-000000000001','33333333-3333-3333-3333-333333333333','C',now()+interval '20 days',180),
 ('dddddddd-0000-0000-0000-000000000001','44444444-4444-4444-4444-444444444444','foreign',now()+interval '20 days',180);
INSERT INTO public.time_windows(user_id,date,start_minute,end_minute)
 SELECT '33333333-3333-3333-3333-333333333333',day,a,b FROM context
 CROSS JOIN (VALUES(480,600),(540,720),(720,840)) slots(a,b);
INSERT INTO public.time_windows(user_id,weekday,start_minute,end_minute)
 SELECT '33333333-3333-3333-3333-333333333333',extract(isodow FROM day)::smallint,960,1080 FROM context;
INSERT INTO public.activities(user_id,kind,label,date,start_minute,end_minute)
 SELECT '33333333-3333-3333-3333-333333333333',kind,kind,day,a,b FROM context
 CROSS JOIN (VALUES('blocked',600,660),('event',780,840)) slots(kind,a,b);
INSERT INTO public.activities(user_id,kind,label,weekday,start_minute,end_minute)
 SELECT '33333333-3333-3333-3333-333333333333','routine','routine',extract(isodow FROM day)::smallint,1020,1080 FROM context;
INSERT INTO public.sessions(id,user_id,task_id,starts_at,ends_at,status,remaining_after,closed_at)
 SELECT id::uuid,'33333333-3333-3333-3333-333333333333','cccccccc-0000-0000-0000-000000000001',
 (day::timestamp+a*interval '1 minute') AT TIME ZONE 'Asia/Jakarta',
 (day::timestamp+b*interval '1 minute') AT TIME ZONE 'Asia/Jakarta',status,remaining,closed FROM context
 CROSS JOIN (VALUES
 ('cccccccc-0000-0000-0000-000000000002',480,540,'planned',NULL::integer,NULL::timestamptz),
 ('cccccccc-0000-0000-0000-000000000003',660,690,'completed',180,now()),
 ('cccccccc-0000-0000-0000-000000000004',540,600,'missed',NULL,now())
 ) slots(id,a,b,status,remaining,closed);
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}';
SELECT result.* FROM (VALUES
 ($$SELECT public.save_task(NULL,'',NULL,now(),60,0)$$,'P0003','empty title'),
 ($$SELECT public.save_task(NULL,'C',NULL,now(),-1,0)$$,'P0003','negative duration'),
 ($$SELECT public.save_task(NULL,'C',NULL,now(),0,0)$$,'P0003','new task needs positive duration'),
 ($$SELECT public.save_task(NULL,'C',NULL,NULL,10,0)$$,'P0003','task deadline required'),
 ($$SELECT public.save_task(NULL,'C',repeat('x',101),now(),10,0)$$,'P0003','course length validated'),
 ($$SELECT public.save_time_window(NULL,1::smallint,NULL,120,60,0)$$,'P0003','reversed window'),
 ($$SELECT public.save_time_window(NULL,NULL,NULL,0,60,0)$$,'P0003','window target required'),
 ($$SELECT public.save_time_window(NULL,8::smallint,NULL,0,60,0)$$,'P0003','invalid weekday'),
 ($$SELECT public.save_time_window(NULL,1::smallint,NULL,NULL,60,0)$$,'P0003','null start minute'),
 ($$SELECT public.save_time_window(NULL,1::smallint,NULL,-1,60,0)$$,'P0003','negative start minute'),
 ($$SELECT public.save_time_window(NULL,1::smallint,NULL,0,1441,0)$$,'P0003','end minute beyond day'),
 ($$SELECT public.save_activity(NULL,'routine','x',NULL,NULL,0,60,0)$$,'P0003','routine needs weekday'),
 ($$SELECT public.save_activity(NULL,NULL,'x',1::smallint,NULL,0,60,0)$$,'P0003','activity kind required'),
 ($$SELECT public.save_activity(NULL,'routine',NULL,1::smallint,NULL,0,60,0)$$,'P0003','activity label required'),
 ($$SELECT public.save_activity(NULL,'routine',repeat('x',121),1::smallint,NULL,0,60,0)$$,'P0003','activity label length'),
 ($$SELECT public.save_activity(NULL,'routine','x',8::smallint,NULL,0,60,0)$$,'P0003','activity weekday range'),
 ($$SELECT public.save_activity(NULL,'routine','x',1::smallint,NULL,0,NULL,0)$$,'P0003','activity end required'),
 ($$SELECT public.delete_task('cccccccc-0000-0000-0000-000000000001',false,0)$$,'P0003','delete requires confirmation'),
 ($$SELECT public.save_task(NULL,'C',NULL,now(),60,NULL)$$,'P0002','null task revision'),
 ($$SELECT public.delete_task('cccccccc-0000-0000-0000-000000000001',true,NULL)$$,'P0002','null delete revision'),
 ($$SELECT public.save_time_window(NULL,1::smallint,NULL,0,60,NULL)$$,'P0002','null window revision'),
 ($$SELECT public.delete_time_window(gen_random_uuid(),NULL)$$,'P0002','null window delete revision'),
 ($$SELECT public.save_activity(NULL,'routine','x',1::smallint,NULL,0,60,NULL)$$,'P0002','null activity revision'),
 ($$SELECT public.delete_activity(gen_random_uuid(),NULL)$$,'P0002','null activity delete revision'),
 ($$SELECT public.record_progress('cccccccc-0000-0000-0000-000000000002','completed',90,NULL)$$,'P0002','null progress revision'),
 ($$SELECT pg_temp.confirm('[]',NULL)$$,'P0002','null confirmation revision'),
 ($$SELECT pg_temp.confirm('[]',1)$$,'P0002','stale confirm preserves old schedule'),
 ($$SELECT pg_temp.confirm(NULL)$$,'P0003','null candidate list'),
 ($$SELECT pg_temp.confirm('{}')$$,'P0003','object instead of array'),
 ($$SELECT pg_temp.confirm('[{}]')$$,'P0003','missing candidate fields'),
 ($$SELECT pg_temp.confirm('[null]')$$,'P0003','null candidate'),
 ($$SELECT pg_temp.confirm('[{"task_id":"bad","starts_at":"bad","ends_at":"bad"}]')$$,'P0003','malformed candidate types'),
 ($$SELECT pg_temp.confirm(jsonb_build_array(pg_temp.candidate(480,540) || '{"starts_at":"bad"}'::jsonb))$$,'P0003','invalid start timestamp with valid task'),
 ($$SELECT pg_temp.confirm(jsonb_build_array(pg_temp.candidate(480,540) || '{"ends_at":"bad"}'::jsonb))$$,'P0003','invalid end timestamp with valid task'),
 ($$SELECT pg_temp.confirm(jsonb_build_array(pg_temp.candidate(480,540) || '{"starts_at":123}'::jsonb))$$,'P0003','non-string timestamp'),
 ($$SELECT pg_temp.confirm(jsonb_build_array(pg_temp.candidate(480,540,'dddddddd-0000-0000-0000-000000000001')))$$,'P0004','foreign candidate task'),
 ($$SELECT pg_temp.confirm(jsonb_build_array(pg_temp.candidate(480,480)))$$,'P0003','zero duration'),
 ($$SELECT pg_temp.confirm(jsonb_build_array(pg_temp.candidate(540,480)))$$,'P0003','reversed session'),
 ($$SELECT pg_temp.confirm(jsonb_build_array(pg_temp.candidate(420,480)))$$,'P0003','outside manual availability'),
 ($$SELECT pg_temp.confirm(jsonb_build_array(pg_temp.candidate(570,630)))$$,'P0003','crosses blocked time'),
 ($$SELECT pg_temp.confirm(jsonb_build_array(pg_temp.candidate(780,810)))$$,'P0003','event blocks time'),
 ($$SELECT pg_temp.confirm(jsonb_build_array(pg_temp.candidate(1020,1050)))$$,'P0003','weekly routine blocks time'),
 ($$SELECT pg_temp.confirm(jsonb_build_array(pg_temp.candidate(660,690)))$$,'P0003','completed history blocks time'),
 ($$SELECT pg_temp.confirm(jsonb_build_array(pg_temp.candidate(480,570),pg_temp.candidate(540,600)))$$,'P0003','candidate overlap'),
 ($$SELECT pg_temp.confirm(jsonb_build_array(pg_temp.candidate(480,600),pg_temp.candidate(690,780)))$$,'P0003','aggregate allocation exceeds remaining'),
 ($$SELECT pg_temp.confirm(jsonb_build_array(pg_temp.candidate(480,540) || jsonb_build_object('ends_at',(pg_temp.candidate(480,540)->>'ends_at')::timestamptz+interval '1 second')))$$,'P0003','fractional minute rejected'),
 ($$SELECT pg_temp.confirm(jsonb_build_array(jsonb_build_object('task_id','cccccccc-0000-0000-0000-000000000001','starts_at',now()-interval '2 minutes','ends_at',now()-interval '1 minute')))$$,'P0003','past candidate'),
 ($$SELECT public.confirm_schedule(0,NULL,(SELECT we FROM pg_temp.context),'[]')$$,'P0003','null horizon'),
 ($$SELECT public.confirm_schedule(0,(SELECT ws FROM pg_temp.context),(SELECT we+interval '1 day' FROM pg_temp.context),'[]')$$,'P0003','wrong WIB horizon'),
 ($$SELECT public.confirm_schedule(0,(SELECT ws FROM pg_temp.context),(SELECT we FROM pg_temp.context),jsonb_build_array(pg_temp.candidate(480,540) || jsonb_build_object('ends_at',(SELECT we+interval '1 minute' FROM pg_temp.context))))$$,'P0003','candidate outside horizon'),
 ($$SELECT pg_temp.confirm(jsonb_build_array(pg_temp.candidate(480,540),pg_temp.candidate(540,600,'dddddddd-0000-0000-0000-000000000001')))$$,'P0004','failure after first insert rolls back cancellation and insert')
) cases(q,code,label) CROSS JOIN LATERAL pg_temp.reject(q,code,label) result;
SELECT * FROM pg_temp.reject($$DO $case$ BEGIN
 PERFORM public.save_task('cccccccc-0000-0000-0000-000000000001','C',NULL,
   (pg_temp.candidate(480,510)->>'ends_at')::timestamptz,180,0);
 PERFORM pg_temp.confirm(jsonb_build_array(pg_temp.candidate(480,540)),1);
 END $case$;$$,'P0003','deadline inside candidate rejects entire transaction');
SELECT * FROM pg_temp.reject($$DO $case$ BEGIN
 PERFORM public.save_task('cccccccc-0000-0000-0000-000000000001','C',NULL,now()+interval '20 days',0,0);
 PERFORM pg_temp.confirm(jsonb_build_array(pg_temp.candidate(480,540)),1);
 END $case$;$$,'P0003','completed task cannot receive allocation');
SELECT is(public.get_planner_snapshot()->'sessions'->0->>'status','planned','original schedule still planned');
SELECT is(pg_temp.confirm(jsonb_build_array(
 pg_temp.candidate(480,600) || '{"user_id":"44444444-4444-4444-4444-444444444444"}'::jsonb,
 pg_temp.candidate(690,750))),1::bigint,'merged/adjacent windows, exact capacity, missed reuse, and completed boundary');
SELECT is((SELECT count(*) FROM public.sessions WHERE status='planned' AND user_id=auth.uid()),2::bigint,'spoofed JSON owner cannot choose session owner');
SELECT is((SELECT status FROM public.sessions WHERE id='cccccccc-0000-0000-0000-000000000002'),'cancelled','old future plan cancelled');
SELECT is((SELECT count(*) FROM public.sessions WHERE status IN ('completed','missed')),2::bigint,'history preserved');
SELECT * FROM pg_temp.reject($$SELECT pg_temp.confirm('[]',0)$$,'P0002','same revision cannot confirm twice');
SELECT is(pg_temp.confirm('[]',1),2::bigint,'empty candidate list atomically cancels future plans');
SELECT is((SELECT count(*) FROM public.sessions WHERE status='planned'),0::bigint,'empty confirmation leaves no planned sessions');
SELECT is(pg_temp.confirm(jsonb_build_array(pg_temp.candidate(960,1020)),2),3::bigint,'weekly availability and adjacent routine boundary');
-- Progress fixtures represent sessions that have started; reset only as DB owner.
RESET ROLE;
INSERT INTO public.sessions(id,user_id,task_id,starts_at,ends_at,status)
 SELECT id::uuid,'33333333-3333-3333-3333-333333333333','cccccccc-0000-0000-0000-000000000001',
 date_trunc('minute',now())-interval '2 hours',date_trunc('minute',now())-interval '1 hour','planned'
 FROM (VALUES('cccccccc-0000-0000-0000-000000000005'),('cccccccc-0000-0000-0000-000000000006'),('cccccccc-0000-0000-0000-000000000007')) ids(id);
SET LOCAL ROLE authenticated;
SELECT * FROM pg_temp.reject($$SELECT pg_temp.confirm('[]',3)$$,'P0003','started unclosed plan blocks confirm');
SELECT * FROM pg_temp.reject($$SELECT public.record_progress('cccccccc-0000-0000-0000-000000000005','missed',10,3)$$,'P0003','missed requires null remaining');
SELECT * FROM pg_temp.reject($$SELECT public.record_progress('cccccccc-0000-0000-0000-000000000005',NULL,NULL,3)$$,'P0003','null progress status');
SELECT * FROM pg_temp.reject($$SELECT public.record_progress('cccccccc-0000-0000-0000-000000000005','completed',-1,3)$$,'P0003','negative progress');
SELECT * FROM pg_temp.reject($$SELECT public.record_progress('cccccccc-0000-0000-0000-000000000005','completed',NULL,3)$$,'P0003','completed requires remaining');
SELECT * FROM pg_temp.reject($$SELECT public.record_progress((SELECT id FROM public.sessions WHERE status='planned' AND starts_at>now() LIMIT 1),'completed',90,3)$$,'P0003','future session cannot close');
SELECT is(public.record_progress('cccccccc-0000-0000-0000-000000000005','missed',NULL,3),4::bigint,'missed closes once');
SELECT is((SELECT remaining_minutes FROM public.tasks WHERE title='C'),180,'missed preserves remaining');
SELECT is(public.record_progress('cccccccc-0000-0000-0000-000000000006','completed',90,4),5::bigint,'completed closes once');
SELECT is((SELECT remaining_minutes FROM public.tasks WHERE title='C'),90,'completed sets exact remaining 90');
SELECT * FROM pg_temp.reject($$SELECT public.record_progress('cccccccc-0000-0000-0000-000000000006','completed',0,5)$$,'P0005','double close rejected at fresh revision');
SELECT * FROM pg_temp.reject($$SELECT public.record_progress('cccccccc-0000-0000-0000-000000000005','completed',0,4)$$,'P0002','double close rejected at stale revision');
SELECT is(public.record_progress('cccccccc-0000-0000-0000-000000000007','completed',240,5),6::bigint,'progress may increase remaining estimate');
SELECT is((SELECT remaining_minutes FROM public.tasks WHERE title='C'),240,'increased estimate stored exactly');
SELECT is(public.save_task('cccccccc-0000-0000-0000-000000000001','C',NULL,now()+interval '20 days',240,6),7::bigint,'task edit increments revision once');
SELECT * FROM pg_temp.reject($$SELECT public.delete_task('cccccccc-0000-0000-0000-000000000001',false,7)$$,'P0003','cancel delete preserves task and history');
SELECT is(public.delete_task('cccccccc-0000-0000-0000-000000000001',true,7),8::bigint,'confirmed deletion increments once');
SELECT is((SELECT count(*) FROM public.tasks),0::bigint,'task deleted');
SELECT is((SELECT count(*) FROM public.sessions),0::bigint,'all task sessions cascaded');
SELECT * FROM finish();
ROLLBACK;
