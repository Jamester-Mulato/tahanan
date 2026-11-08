import crypto from "node:crypto";

interface Challenge {
  answer: string;
  question: string;
  expiresAt: number;
}

const TTL_MS = 5 * 60 * 1000;
const MAX_CHALLENGES = 5000;
const challenges = new Map<string, Challenge>();

function cleanup() {
  const now = Date.now();
  for (const [id, challenge] of challenges) {
    if (challenge.expiresAt <= now) challenges.delete(id);
  }

  while (challenges.size > MAX_CHALLENGES) {
    const oldest = challenges.keys().next().value;
    if (!oldest) break;
    challenges.delete(oldest);
  }
}

/**
 * A server-side challenge whose answer never leaves the server. The client
 * receives only the question and a single-use id.
 */
export function createCaptcha() {
  cleanup();

  const first = crypto.randomInt(2, 10);
  const second = crypto.randomInt(2, 10);
  const addition = crypto.randomInt(0, 2) === 0;

  // Avoid a subtraction like "4 - 4" (answer 0) which looks like a mistake.
  const high =
    addition || first !== second ? Math.max(first, second) : Math.max(first, second) + 1;
  const low = Math.min(first, second);

  const question = addition
    ? `What is ${first} + ${second}?`
    : `What is ${high} - ${low}?`;
  const answer = addition ? first + second : high - low;

  const id = crypto.randomBytes(18).toString("hex");
  challenges.set(id, {
    answer: String(answer),
    question,
    expiresAt: Date.now() + TTL_MS
  });

  return {
    id,
    question,
    expiresIn: Math.floor(TTL_MS / 1000)
  };
}

/** Single use: whether the answer is right or wrong, the challenge is gone. */
export function verifyCaptcha(id: string, answer: string): boolean {
  cleanup();

  const challenge = challenges.get(id);
  if (!challenge) return false;

  challenges.delete(id);

  if (challenge.expiresAt <= Date.now()) return false;
  return challenge.answer === String(answer).trim();
}
