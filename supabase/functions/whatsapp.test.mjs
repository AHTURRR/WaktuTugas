import assert from "node:assert/strict";
import { test } from "node:test";
import { generateCode, mac, normalizePhone, openWA, supabaseBackend } from "./_shared/whatsapp.mjs";
import { settingsHandler } from "./whatsapp-settings/handler.mjs";
import { remindersHandler } from "./send-task-reminders/handler.mjs";

const secret = "only-for-local-tests-000000000000000000";
const request = (body, headers = {}) => new Request("https://test.invalid", {
  method: "POST", headers: { "content-type": "application/json", ...headers },
  body: JSON.stringify(body),
});
const example = { url: "https://openwa.test", session: "test-session", key: "test-operator" };

test("server normalizes Indonesian mobile numbers and rejects other inputs", async () => {
  assert.equal(normalizePhone("0812-0000 0001"), "+6281200000001");
  assert.equal(normalizePhone(" +6281200000001 "), "+6281200000001");
  for (const input of [null, 81200000001, "+628", "+62120000001", "6281200000001",
    "081200000001@c.us", "+6281234567890123", "٠٨١٢٠٠٠٠٠٠٠١"]) {
    assert.equal(normalizePhone(input), null);
  }
  assert.match(generateCode(), /^\d{6}$/);
  assert.notEqual(await mac(secret, "a", "012345"), await mac(secret, "b", "012345"));
});

test("OpenWA contract, replay and ambiguous outcomes", async () => {
  assert.throws(() => openWA({ ...example, url: "http://openwa.test" }));
  const pending = [
    [201, { messageId: "mock-1" }], [201, { messageId: "mock-1" }],
    [409, { code: "IDEMPOTENCY_OUTCOME_UNKNOWN" }], [409, { code: "IDEMPOTENCY_KEY_IN_PROGRESS" }],
    [429, {}], [503, {}], [422, {}], [401, {}], [201, {}],
  ];
  const send = openWA(example, async (url, init) => {
    assert.equal(url.href, "https://openwa.test/api/sessions/test-session/messages/send-text");
    assert.equal(init.method, "POST");
    assert.equal(init.headers["X-API-Key"], example.key);
    assert.equal(init.headers["Idempotency-Key"], "stable");
    assert.deepEqual(JSON.parse(init.body), {
      chatId: "6281200000001@c.us", text: "message", linkPreview: false,
    });
    const [status, body] = pending.shift();
    return Response.json(body, { status });
  });
  for (const expected of ["accepted", "accepted", "uncertain", "retry",
    "retry", "retry", "uncertain", "failed", "uncertain"]) {
    assert.equal(await send("+6281200000001", "message", "stable"), expected);
  }
  assert.equal(await openWA(example, () => { throw new Error("timeout"); })(
    "+6281200000001", "message", "stable",
  ), "retry");
});

const url = process.env.WA_TEST_SUPABASE_URL;
const service = process.env.WA_TEST_SERVICE_ROLE_KEY;

test("local Supabase auth, OTP and parallel/retry workers with mock OpenWA", {
  skip: !url || !service,
}, async (t) => {
  const config = new Map([["SUPABASE_URL", url], ["SUPABASE_SERVICE_ROLE_KEY", service]]);
  const backend = supabaseBackend(config);
  async function api(path, method, body, token = service) {
    const response = await fetch(url + path, {
      method, headers: {
        apikey: service, authorization: "Bearer " + token,
        "content-type": "application/json", prefer: "return=representation",
      }, body: body === undefined ? undefined : JSON.stringify(body),
    });
    assert.ok(response.ok, method + " " + path.split("?")[0] + " status " + response.status);
    const text = await response.text();
    return text ? JSON.parse(text) : null;
  }
  async function account() {
    const email = crypto.randomUUID() + "@example.test";
    const password = crypto.randomUUID();
    const user = await api("/auth/v1/admin/users", "POST", { email, password, email_confirm: true });
    t.after(() => api("/auth/v1/admin/users/" + user.id, "DELETE"));
    const session = await api("/auth/v1/token?grant_type=password", "POST", { email, password });
    return { user: user.id, token: session.access_token };
  }
  const a = await account();
  const b = await account();
  const phone = "+6281" + String(crypto.getRandomValues(new Uint32Array(1))[0] % 1000000000).padStart(9, "0");
  const observed = new Map();
  let ambiguous = true;
  const send = openWA(example, async (endpoint, init) => {
    assert.equal(endpoint.pathname, "/api/sessions/test-session/messages/send-text");
    const key = init.headers["Idempotency-Key"];
    const body = JSON.parse(init.body);
    if (observed.has(key)) assert.deepEqual(observed.get(key), body);
    observed.set(key, body);
    if (key.startsWith("wt-deadline-") && ambiguous) {
      ambiguous = false;
      // Simulate acceptance whose response was lost, then an idempotent replay.
      throw new Error("connection lost");
    }
    return Response.json({ messageId: "mock-accepted" }, { status: 201 });
  });
  const settings = settingsHandler(backend, send, secret, () => "012345");
  const worker = remindersHandler(backend, send, secret);
  const call = (token, action, extra = {}) =>
    settings(request({ action, ...extra }, { authorization: "Bearer " + token }));
  const job = () => worker(request({}, { "x-reminder-cron-secret": secret }));
  assert.equal((await settings(new Request("https://test.invalid", { method: "OPTIONS" }))).status, 204);
  assert.equal((await worker(request({}))).status, 401);
  assert.equal((await call("invalid", "status")).status, 401);
  assert.equal((await call(a.token, "enable", { enabled: true })).status, 409);
  const issued = await call(a.token, "request_code", { phone: "0" + phone.slice(3) });
  assert.equal(issued.status, 200);
  const state = await issued.json();
  assert.ok(state.awaiting_code);
  assert.ok(!JSON.stringify(state).includes(phone));
  assert.equal([...observed.values()][0].chatId, phone.slice(1) + "@c.us");
  assert.match([...observed.values()][0].text, /012345/);
  assert.equal((await call(a.token, "resend_code")).status, 429);
  assert.equal((await (await call(b.token, "status", { user_id: a.user })).json()).phone, null);
  assert.equal((await call(b.token, "verify_code", { code: "012345" })).status, 409);
  assert.equal((await call(a.token, "verify_code", { code: "543210" })).status, 409);
  const verified = await call(a.token, "verify_code", { code: "012345" });
  assert.deepEqual([verified.status, (await verified.json()).verified], [200, true]);
  assert.equal((await call(a.token, "verify_code", { code: "012345" })).status, 409);

  const [task] = await api("/rest/v1/tasks", "POST", {
    user_id: a.user, title: "Tugas integrasi", remaining_minutes: 10,
    deadline_at: new Date(Date.now() + 86340000).toISOString(),
  });
  assert.deepEqual(await (await job()).json(), {});
  assert.equal((await (await call(a.token, "enable", { enabled: true })).json()).enabled, true);
  const results = await Promise.all([job(), job()]);
  assert.ok(results.every((response) => response.status === 200));
  const byTask = "/rest/v1/whatsapp_deliveries?task_id=eq." + task.id;
  const [queued] = await api(byTask, "GET");
  assert.equal(queued.status, "queued");
  assert.equal(queued.attempt, 1);
  await api(byTask, "PATCH", { available_at: new Date(0).toISOString() });
  assert.deepEqual(await (await job()).json(), { accepted: 1 });
  assert.deepEqual(await (await job()).json(), {});
  const [accepted] = await api(byTask, "GET");
  assert.equal(accepted.status, "accepted");
  assert.equal(accepted.attempt, 2);
  assert.equal([...observed.keys()].filter((key) => key.startsWith("wt-deadline-")).length, 1);
  assert.equal((await (await call(a.token, "enable", { enabled: false })).json()).enabled, false);
  assert.equal((await (await call(a.token, "enable", { enabled: true })).json()).enabled, true);
  const replacement = phone.slice(0, -1) + ((Number(phone.at(-1)) + 1) % 10);
  await api("/rest/v1/whatsapp_code_requests?user_id=eq." + a.user, "PATCH", {
    requested_at: new Date(Date.now() - 120000).toISOString(),
  });
  const changed = await call(a.token, "request_code", { phone: replacement });
  const next = await changed.json();
  assert.deepEqual([changed.status, next.verified, next.enabled, next.awaiting_code], [200, false, false, true]);
  assert.equal((await call(a.token, "enable", { enabled: true })).status, 409);
});
