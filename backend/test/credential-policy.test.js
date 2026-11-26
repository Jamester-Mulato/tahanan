const test = require("node:test");
const assert = require("node:assert/strict");
const {
  lockoutFor,
  passwordProblem,
  usernameProblem
} = require("../dist/services/credential-policy");
const { env } = require("../dist/config/env");

test("lockout: only the 3rd, 6th and 9th+ consecutive failures lock", () => {
  for (const attempts of [1, 2, 4, 5, 7, 8]) {
    assert.equal(lockoutFor(attempts), null, `attempt ${attempts} must not lock`);
  }

  const first = lockoutFor(3);
  assert.equal(first.seconds, env.LOCKOUT_TIER1_SECONDS);
  assert.equal(first.event, "LOCKOUT_TIER_1");

  const second = lockoutFor(6);
  assert.equal(second.seconds, env.LOCKOUT_TIER2_SECONDS);
  assert.equal(second.event, "LOCKOUT_TIER_2");

  for (const attempts of [9, 10, 40]) {
    const third = lockoutFor(attempts);
    assert.equal(third.seconds, env.LOCKOUT_TIER3_SECONDS);
    assert.equal(third.event, "LOCKOUT_TIER_3");
  }
});

test("password: one rule for every caller", () => {
  assert.equal(passwordProblem("Abcdefgh1"), null);
  assert.match(passwordProblem("Abcdefg1"), /at least 9/);
  assert.match(passwordProblem("abcdefgh1"), /uppercase/);
  assert.match(passwordProblem("Abcdefghi"), /number/);
  assert.match(passwordProblem("A1"), /at least 9/);
  assert.match(passwordProblem(`A1${"x".repeat(63)}`), /at most 64/);
});

test("username: 7-16, starts with a letter, letters and digits only", () => {
  assert.equal(usernameProblem("jamester"), null);
  assert.equal(usernameProblem("Abc1234"), null);
  assert.match(usernameProblem("abcdef"), /at least 7/);
  assert.match(usernameProblem("abcdefghijklmnopq"), /at most 16/);
  assert.match(usernameProblem("1abcdefg"), /start with a letter/);
  assert.match(usernameProblem("abc_defg"), /letters and digits/);
  assert.match(usernameProblem("abc defg"), /letters and digits/);
});
