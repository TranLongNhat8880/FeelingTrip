const { test, beforeEach, afterEach } = require("node:test");
const assert = require("node:assert/strict");
const { Writable } = require("node:stream");
const repository = require("../src/features/users/identity.repository");
const cloudinary = require("../src/config/cloudinary");
const service = require("../src/features/users/identity.service");
const originalUrl = process.env.EKYC_WORKER_URL,
  originalKey = process.env.EKYC_WORKER_KEY;
beforeEach(() => {
  process.env.EKYC_WORKER_URL = "http://identity.test:5101";
  process.env.EKYC_WORKER_KEY =
    "identity-unit-test-key-with-at-least-32-characters";
});
afterEach(() => {
  if (originalUrl === undefined) delete process.env.EKYC_WORKER_URL;
  else process.env.EKYC_WORKER_URL = originalUrl;
  if (originalKey === undefined) delete process.env.EKYC_WORKER_KEY;
  else process.env.EKYC_WORKER_KEY = originalKey;
});
const payload = () => ({
  userId: "owner",
  sessionId: "session",
  cccdNumber: "001201012345",
  qrData: "test-qr",
  files: Object.fromEntries(
    ["cccdFrontImage", "cccdBackImage", "selfieImage", "livenessVideo"].map(
      (field) => [field, [{ buffer: Buffer.from("test-evidence") }]],
    ),
  ),
});
const passed = () => ({
  verified: true,
  documentMatched: true,
  livenessPassed: true,
  faceMatched: true,
  padPassed: true,
  cccdNumber: "001201012345",
  model: "SFace-2021dec",
  code: "VERIFIED",
  faceScores: [0.8, 0.82, 0.85],
  padScores: [0.96, 0.97],
});
function setup(t, result = passed()) {
  const finished = [],
    uploads = [],
    deleted = [];
  let approvals = 0;
  t.mock.method(repository, "consumeSession", async (user, session) => {
    assert.equal(user, "owner");
    assert.equal(session, "session");
    return { id: session, actions: ["blink", "turnLeft", "turnRight"] };
  });
  t.mock.method(repository, "finishSession", async (id, status, audit) => {
    finished.push({ id, status, audit });
  });
  t.mock.method(repository, "approve", async (data) => {
    approvals++;
    assert.equal(data.result.verified, true);
    return { verification_status: "VERIFIED", is_verified: true };
  });
  t.mock.method(global, "fetch", async (url, options) => {
    assert.equal(url, "http://identity.test:5101/verify");
    assert.equal(options.redirect, "error");
    assert.deepEqual(JSON.parse(options.body.get("actions")), [
      "blink",
      "turnLeft",
      "turnRight",
    ]);
    assert.ok(options.body.get("livenessVideo") instanceof Blob);
    return new Response(JSON.stringify(result), {
      status: 200,
      headers: { "content-type": "application/json" },
    });
  });
  t.mock.method(cloudinary.uploader, "upload_stream", (options, done) => {
    assert.equal(options.type, "authenticated");
    assert.equal(options.resource_type, "image");
    const id = `asset-${uploads.length}`;
    uploads.push(options);
    return new Writable({
      write(chunk, encoding, callback) {
        callback();
      },
      final(callback) {
        done(null, {
          public_id: id,
          secure_url: `https://media.test/authenticated/${id}`,
        });
        callback();
      },
    });
  });
  t.mock.method(cloudinary.uploader, "destroy", async (id, options) => {
    assert.equal(options.type, "authenticated");
    deleted.push(id);
  });
  return {
    finished,
    uploads,
    deleted,
    get approvals() {
      return approvals;
    },
  };
}
test("only complete server evidence can auto verify; images use authenticated storage", async (t) => {
  const state = setup(t);
  const result = await service.verify(payload());
  assert.equal(result.isVerified, true);
  assert.equal(state.approvals, 1);
  assert.equal(state.uploads.length, 3);
  assert.deepEqual(state.deleted, []);
});
test("truthy strings, absent PAD, low or invalid scores and document mismatch never approve", async (t) => {
  for (const override of [
    { verified: "true" },
    { documentMatched: false },
    { padPassed: false },
    { faceScores: [0.8, 0.9] },
    { faceScores: [0.8, 0.49, 0.8] },
    { padScores: [0.89, 0.99] },
    { padScores: [".99", 0.99] },
    { cccdNumber: "001201012346" },
    { model: "unrecognized" },
    { livenessPassed: false },
    { faceMatched: false },
  ]) {
    await t.test(JSON.stringify(override), async (child) => {
      const state = setup(child, { ...passed(), ...override });
      await assert.rejects(service.verify(payload()), { statusCode: 422 });
      assert.equal(state.approvals, 0);
      assert.equal(state.uploads.length, 0);
      assert.equal(state.finished.at(-1).status, "FAILED");
    });
  }
});
test("worker outage never stores or verifies a user", async (t) => {
  const state = setup(t);
  t.mock.method(global, "fetch", async () => {
    throw new Error("offline");
  });
  await assert.rejects(service.verify(payload()), { statusCode: 503 });
  assert.equal(state.approvals, 0);
  assert.equal(state.uploads.length, 0);
  assert.equal(state.finished[0].status, "ERROR");
});
test("a failed database commit cleans up all authenticated images", async (t) => {
  const state = setup(t);
  t.mock.method(repository, "approve", async () => {
    throw new Error("database disconnected");
  });
  await assert.rejects(service.verify(payload()), { statusCode: 503 });
  assert.equal(state.deleted.length, 3);
  assert.equal(state.finished.at(-1).status, "ERROR");
});
test("missing video or oversized image is rejected before consuming a session", async (t) => {
  const state = setup(t);
  const consume = t.mock.method(repository, "consumeSession", async () => {
    throw new Error("must not consume");
  });
  const missing = payload();
  delete missing.files.livenessVideo;
  await assert.rejects(service.verify(missing), { statusCode: 400 });
  const large = payload();
  large.files.cccdFrontImage[0].buffer = Buffer.alloc(5 * 1024 * 1024 + 1);
  await assert.rejects(service.verify(large), { statusCode: 413 });
  assert.equal(consume.mock.callCount(), 0);
  assert.equal(state.approvals, 0);
});
test("worker health gates session creation without trusting a client flag", async (t) => {
  const create = t.mock.method(repository, "createSession", async () => ({
    sessionId: "new",
  }));
  t.mock.method(
    global,
    "fetch",
    async () => new Response(JSON.stringify({ ready: false }), { status: 200 }),
  );
  await assert.rejects(service.createSession("owner"), { statusCode: 503 });
  assert.equal(create.mock.callCount(), 0);
});
test("missing credentials and invalid worker URL fail with a public configuration error", async () => {
  delete process.env.EKYC_WORKER_KEY;
  await assert.rejects(service.createSession("owner"), {
    statusCode: 503,
    expose: true,
  });
  process.env.EKYC_WORKER_KEY = "x".repeat(40);
  process.env.EKYC_WORKER_URL = "invalid";
  await assert.rejects(service.createSession("owner"), {
    statusCode: 503,
    expose: true,
  });
});
