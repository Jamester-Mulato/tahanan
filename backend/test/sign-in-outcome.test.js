const test = require("node:test");
const assert = require("node:assert/strict");
const { signInError } = require("../dist/services/sign-in.service");

test("sign-in outcomes map to one HTTP contract", () => {
  const ip = signInError({ kind: "ip-blocked", retryAfter: 42 });
  assert.equal(ip.status, 429);
  assert.equal(ip.code, "IP_BLOCKED");
  assert.equal(ip.details.retryAfter, 42);

  const locked = signInError({ kind: "account-locked", retryAfter: 16 });
  assert.equal(locked.status, 423);
  assert.equal(locked.code, "ACCOUNT_LOCKED");
  assert.equal(locked.details.retryAfter, 16);

  const rejected = signInError({ kind: "rejected", attempts: 2 });
  assert.equal(rejected.status, 401);
  assert.equal(rejected.code, "INVALID_CREDENTIALS");
  assert.equal(rejected.details.attempts, 2);

  for (const error of [ip, locked, rejected]) {
    assert.ok(error instanceof Error);
    assert.ok(error.message.length > 0);
  }
});
