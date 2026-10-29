/**
 * An error that is safe to show to the caller. Anything else becomes a generic
 * 500 so internal details never leak through the API.
 */
export class HttpError extends Error {
  constructor(
    public readonly status: number,
    public readonly code: string,
    message: string,
    public readonly details?: Record<string, unknown>
  ) {
    super(message);
    this.name = "HttpError";
  }
}
