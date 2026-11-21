import fs from "node:fs";
import path from "node:path";

const BASE = "http://localhost:8080/api/auth";
const ME = "http://localhost:8080/api/me";
const LOG = path.resolve(process.cwd(), "server.out.log");

let passed = 0;
let failed = 0;

function check(label, condition, extra = "") {
  if (condition) {
    passed += 1;
    console.log(`PASS  ${label}`);
  } else {
    failed += 1;
    console.log(`FAIL  ${label}${extra ? ` — ${extra}` : ""}`);
  }
}

async function captcha() {
  const response = await fetch(`${BASE}/captcha`);
  const challenge = await response.json();
  const numbers = [...challenge.question.matchAll(/\d+/g)].map((m) =>
    Number(m[0])
  );
  const answer = challenge.question.includes("+")
    ? numbers[0] + numbers[1]
    : Math.max(...numbers) - Math.min(...numbers);
  return { captchaId: challenge.id, captchaAnswer: String(answer) };
}

async function post(route, body) {
  const response = await fetch(`${BASE}${route}`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body),
  });
  const text = await response.text();
  let data;
  try {
    data = JSON.parse(text);
  } catch {
    data = text;
  }
  return { status: response.status, data };
}

async function getMe(token) {
  const response = await fetch(ME, {
    headers: { authorization: `Bearer ${token}` },
  });
  return response.status;
}

const email = `authflow${Date.now()}@example.com`;
const password = "Tahanan123";
const newPassword = "Tahanan456";

console.log(`Account: ${email}`);

// 1. Register
const register = await post("/register", {
  displayName: "Auth Flow",
  email,
  password,
  ...(await captcha()),
  rememberMe: true,
});
check(
  "register returns access + refresh + remember tokens",
  register.status === 201 &&
    typeof register.data.accessToken === "string" &&
    typeof register.data.refreshToken === "string" &&
    typeof register.data.rememberToken === "string",
  JSON.stringify(register.data)
);

const access = register.data.accessToken;
const refresh = register.data.refreshToken;
const remember = register.data.rememberToken;

// 2. Refresh rotation
const refreshed = await post("/refresh", { refreshToken: refresh });
check(
  "refresh rotates the token pair",
  refreshed.status === 200 &&
    refreshed.data.refreshToken &&
    refreshed.data.refreshToken !== refresh
);

// 3. The old refresh token must be dead
const reused = await post("/refresh", { refreshToken: refresh });
check("old refresh token is rejected", reused.status === 401);

// 4. Sessions
const sessionsResponse = await fetch(`${BASE}/sessions`, {
  headers: { authorization: `Bearer ${refreshed.data.accessToken}` },
});
const sessions = await sessionsResponse.json();
check(
  "sessions lists active refresh tokens",
  sessionsResponse.status === 200 && Array.isArray(sessions.sessions)
);

// 5. Login with remember token skips the CAPTCHA
const rememberedLogin = await post("/login", {
  email,
  password,
  rememberToken: remember,
  rememberMe: true,
});
check(
  "remembered login skips CAPTCHA",
  rememberedLogin.status === 200 && rememberedLogin.data.accessToken,
  JSON.stringify(rememberedLogin.data)
);

// 6. Logout-all revokes the access token
const logoutAll = await post("/logout-all", {});
check(
  "logout-all requires a token",
  logoutAll.status === 401
);
const logoutWithAuth = await fetch(`${BASE}/logout-all`, {
  method: "POST",
  headers: {
    authorization: `Bearer ${rememberedLogin.data.accessToken}`,
    "content-type": "application/json",
  },
  body: "{}",
});
check("logout-all succeeds", logoutWithAuth.status === 200);
check(
  "old access token is rejected after logout-all",
  (await getMe(rememberedLogin.data.accessToken)) === 401
);

// 7. Fresh login, then lockout after repeated failures
const login = await post("/login", {
  email,
  password,
  ...(await captcha()),
});
check("normal login succeeds", login.status === 200);

let lockedStatus = 0;
for (let attempt = 1; attempt <= 5; attempt += 1) {
  const result = await post("/login", {
    email,
    password: "Wrong123",
    ...(await captcha()),
  });
  lockedStatus = result.status;
}
check("fifth wrong password locks the account", lockedStatus === 423);

// 8. Forgot + reset password (dev token is written to server.out.log)
const forgot = await post("/forgot-password", { email });
check("forgot-password is generic", forgot.status === 200);

await new Promise((resolve) => setTimeout(resolve, 300));
const logText = fs.existsSync(LOG) ? fs.readFileSync(LOG, "utf8") : "";
const match = [...logText.matchAll(/\[dev-password-reset\]\s+(\S+)\s+(\S+)/g)]
  .filter((m) => m[1] === email)
  .pop();
check("reset token was issued to the development log", Boolean(match));

if (match) {
  const reset = await post("/reset-password", {
    token: match[2],
    password: newPassword,
  });
  check("reset-password succeeds", reset.status === 200);

  const afterReset = await post("/login", {
    email,
    password: newPassword,
    ...(await captcha()),
  });
  check(
    "login with the new password succeeds after reset",
    afterReset.status === 200,
    JSON.stringify(afterReset.data)
  );
}

// 9. Password change
if (match) {
  const login2 = await post("/login", {
    email,
    password: newPassword,
    ...(await captcha()),
  });
  const change = await fetch(`${BASE}/password`, {
    method: "POST",
    headers: {
      authorization: `Bearer ${login2.data.accessToken}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      currentPassword: newPassword,
      newPassword: "Tahanan789",
    }),
  });
  check("authenticated password change succeeds", change.status === 200);
  check(
    "access token is invalidated by the password change",
    (await getMe(login2.data.accessToken)) === 401
  );
}

console.log(`\n${passed} passed, ${failed} failed`);
process.exit(failed > 0 ? 1 : 0);
