/**
 * Question bank from the handout (section 5).
 * Student 241-00315: D1 = 1, D2 = 5.
 *   A = Q[(5 mod 8) + 1] = Q6
 *   B = Q[((5 + 3) mod 8) + 1] = Q1
 *   C = Q[((5 + 5) mod 8) + 1] = Q3
 */
export const QUESTIONS: Record<string, string> = {
  Q1: "What was the name of your first pet?",
  Q2: "Who was your best friend in elementary school?",
  Q3: "Who was your favorite teacher in high school?",
  Q4: "What is your mother's maiden first name?",
  Q5: "What street did you live on in Grade 1?",
  Q6: "What was the first song you learned by heart?",
  Q7: "What was the name of your elementary school?",
  Q8: "What dish did you cook for the first time?"
};

export const SEEDED_QUESTIONS = {
  A: { key: "Q6", text: QUESTIONS.Q6 },
  B: { key: "Q1", text: QUESTIONS.Q1 },
  C: { key: "Q3", text: QUESTIONS.Q3 }
} as const;

export const SEEDED_KEYS = ["Q6", "Q1", "Q3"] as const;

export function questionText(key: string): string {
  return QUESTIONS[String(key).toUpperCase()] ?? String(key);
}
