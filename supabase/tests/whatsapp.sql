BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path = public, extensions, pg_temp;
SELECT no_plan();

INSERT INTO auth.users(id, email) VALUES
 ('aaaaaaaa-0010-0000-0000-000000000001', 'wa-a@example.invalid'),
 ('bbbbbbbb-0010-0000-0000-000000000002', 'wa-b@example.invalid');
CREATE TEMP TABLE fixture AS SELECT
 'aaaaaaaa-0010-0000-0000-000000000001'::uuid a,
 'bbbbbbbb-0010-0000-0000-000000000002'::uuid b,
 'aaaaaaaa-0010-0000-0000-000000000003'::uuid challenge,
 '+6281200000001'::text phone,
 '+6281200000002'::text other;

SELECT is(whatsapp_request_code(a, '0812', 'phone', challenge, 'mac'), 'invalid_phone', 'SQL validates number') FROM fixture;
SELECT is(whatsapp_request_code(a, phone, 'phone', challenge, 'mac'), 'issued', 'issue challenge') FROM fixture;
SELECT is(whatsapp_request_code(a, other, 'other', challenge, 'mac'), 'rate_limited', 'cooldown survives changing phone') FROM fixture;
SELECT is(whatsapp_set_enabled(a, true), false, 'unverified cannot opt in') FROM fixture;
SELECT is(whatsapp_verify_code(a, challenge, 'bad'), 'wrong_code', 'wrong code') FROM fixture;
SELECT is(whatsapp_verify_code(b, challenge, 'mac'), 'expired', 'challenge cannot be used by another account') FROM fixture;
UPDATE whatsapp_settings SET expires_at = now() WHERE user_id = (SELECT a FROM fixture);
SELECT is(whatsapp_verify_code(a, challenge, 'mac'), 'expired', 'expired code rejected') FROM fixture;
UPDATE whatsapp_settings SET expires_at = now() + interval '1 minute', attempts = 4 WHERE user_id = (SELECT a FROM fixture);
SELECT is(whatsapp_verify_code(a, challenge, 'bad'), 'attempts_exhausted', 'fifth incorrect attempt exhausts code') FROM fixture;
SELECT is(whatsapp_verify_code(a, challenge, 'mac'), 'attempts_exhausted', 'correct code cannot bypass limit') FROM fixture;
UPDATE whatsapp_code_requests SET requested_at = now() - interval '2 minutes';
SELECT is(whatsapp_request_code(a, phone, 'phone', challenge, 'mac'), 'issued', 'resend after cooldown') FROM fixture;
SELECT is(whatsapp_verify_code(a, challenge, 'mac'), 'verified', 'correct code verifies') FROM fixture;
SELECT is(whatsapp_verify_code(a, challenge, 'mac'), 'expired', 'code cannot be replayed') FROM fixture;
SELECT ok((SELECT code_mac IS NULL FROM whatsapp_settings WHERE user_id = a), 'MAC cleared after verification') FROM fixture;
SELECT is(whatsapp_set_enabled(a, true), true, 'verified account can opt in') FROM fixture;
UPDATE whatsapp_code_requests SET requested_at = now() - interval '2 minutes';
SELECT is(whatsapp_request_code(a, other, 'other', challenge, 'othermac'), 'issued', 'change number') FROM fixture;
SELECT ok((SELECT NOT enabled AND verified_at IS NULL AND phone = other FROM whatsapp_settings WHERE user_id = a), 'changing number clears opt-in and verification') FROM fixture;
SELECT is(whatsapp_request_code(b, phone, 'phone', challenge, 'mac'), 'issued', 'other account can request') FROM fixture;
SELECT is(whatsapp_verify_code(b, challenge, 'mac'), 'verified', 'other account verified') FROM fixture;
UPDATE whatsapp_code_requests SET requested_at = now() - interval '2 minutes';
SELECT is(whatsapp_request_code(b, phone, 'phone', challenge, 'mac'), 'already_verified', 'same verified number does not issue a new code') FROM fixture;
SELECT is(whatsapp_request_code(a, phone, 'phone', challenge, 'mac'), 'rate_limited', 'hourly cap per user') FROM fixture;
-- Three requests to phone across A and B, independent of B's user-level quota.
UPDATE whatsapp_settings SET verified_at = NULL WHERE user_id = (SELECT b FROM fixture);
SELECT is(whatsapp_request_code(b, phone, 'phone', challenge, 'mac'), 'rate_limited', 'hourly recipient cap across accounts') FROM fixture;
UPDATE whatsapp_settings SET verified_at = now() WHERE user_id = (SELECT b FROM fixture);

SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub = 'bbbbbbbb-0010-0000-0000-000000000002';
SELECT is((SELECT count(user_id) FROM whatsapp_settings), 1::bigint, 'RLS shows own row only');
SELECT is((SELECT count(user_id) FROM whatsapp_settings
    WHERE user_id = 'aaaaaaaa-0010-0000-0000-000000000001'), 0::bigint, 'RLS hides other row');
SELECT throws_ok('SELECT code_mac FROM public.whatsapp_settings', '42501', NULL, 'cannot read verification MAC');
SELECT throws_ok('UPDATE public.whatsapp_settings SET verified_at = now()', '42501', NULL, 'cannot set verified directly');
SELECT throws_ok('SELECT * FROM public.whatsapp_claim_reminders()', '42501', NULL, 'cannot claim job from client');
SELECT throws_ok($q$SELECT public.whatsapp_verify_code(
 'aaaaaaaa-0010-0000-0000-000000000001','aaaaaaaa-0010-0000-0000-000000000003','mac')$q$,
 '42501', NULL, 'cannot invoke private verify RPC');
RESET ROLE;

INSERT INTO tasks(id,user_id,title,deadline_at,remaining_minutes)
SELECT ('dddddddd-0010-0000-0000-00000000000' || n)::uuid,
 b, 'Test ' || n, now() + interval '24 hours', 20 FROM fixture, generate_series(1,5) n;
SELECT is((SELECT count(*) FROM whatsapp_claim_reminders()), 0::bigint, 'disabled account has no jobs');
SELECT is(whatsapp_set_enabled(b, true), true, 'enable B') FROM fixture;
CREATE TEMP TABLE claims AS SELECT * FROM whatsapp_claim_reminders();
SELECT is((SELECT count(*) FROM claims), 5::bigint, 'claim all due rows');
SELECT is((SELECT count(*) FROM whatsapp_claim_reminders()), 0::bigint, 'second run cannot reclaim leased rows');
DELETE FROM tasks WHERE id = 'dddddddd-0010-0000-0000-000000000001';
UPDATE tasks SET remaining_minutes = 0 WHERE id = 'dddddddd-0010-0000-0000-000000000002';
UPDATE tasks SET deadline_at = now() + interval '26 hours' WHERE id = 'dddddddd-0010-0000-0000-000000000003';
SELECT is((SELECT count(*) FROM claims c
    CROSS JOIN LATERAL whatsapp_prepare_reminder(c.id, c.lease)), 2::bigint, 'recheck excludes deleted, complete, and rescheduled');
SELECT is(whatsapp_set_enabled(b, false), true, 'disable after claim') FROM fixture;
SELECT is((SELECT count(*) FROM claims c CROSS JOIN LATERAL whatsapp_prepare_reminder(c.id, c.lease)),
    0::bigint, 'recheck excludes disabled');
SELECT is(whatsapp_set_enabled(b, true), true, 're-enable') FROM fixture;
UPDATE tasks SET deadline_at = now() + interval '23 hours 59 minutes' WHERE id = 'dddddddd-0010-0000-0000-000000000003';
CREATE TEMP TABLE replacement AS SELECT * FROM whatsapp_claim_reminders();
SELECT is((SELECT count(*) FROM replacement), 1::bigint, 'new deadline gets a new claim');
SELECT ok((SELECT id NOT IN (SELECT id FROM claims) FROM replacement), 'new deadline has unique key');
DO $$ BEGIN PERFORM whatsapp_finish_reminder(id, lease, 'accepted') FROM replacement; END $$;
SELECT is((SELECT count(*) FROM whatsapp_claim_reminders()), 0::bigint, 'accepted delivery cannot be claimed again');
SELECT * FROM finish();
ROLLBACK;
