import { retry } from './retry';

interface RequestParams extends RequestInit {
  method?: 'GET' | 'POST' | 'PUT' | 'DELETE';
  query?: Record<string, string>;
  headers?: Record<string, string>;
}

export class HttpError extends Error {
  response: Response;

  constructor(request: Request, response: Response) {
    super(`${request.method} ${request.url} request failed (${response.status}: ${response.statusText})`);
    this.response = response;
  }
}

/**
 * Generic HTTP Client with some batteries included:
 *
 * - Handles rendering of the URL with query parameters
 * - Throws an error on non-OK responses
 * - Automatically retries failed requests
 * - Add some useful meta headers
 * - ...Some other method-specific goodies
 */
export class HttpClient {
  // There isn't any state in this class at the time of this writing, but
  // we may add some in the future to allow for more advanced base configuration.

  /**
   * Issues a request, expecting a JSON response.
   */
  async fetchJson<T>(path: string, params?: RequestParams): Promise<T> {
    const response = await this.fetch(path, params);
    return response.json();
  }

  async fetch(path: string, params: RequestParams = {}): Promise<Response> {
    const url = new URL(path, window.location.origin);

    for (const [key, value] of Object.entries(params.query ?? {})) {
      url.searchParams.set(key, value);
    }

    params.headers ??= {};

    // This header serves as an idempotency token that identifies the sequence
    // of retries of the same request. The backend may use this information to
    // ensure that the same retried request doesn't result in multiple accumulated
    // side-effects.
    params.headers['X-Retry-Sequence-Id'] = generateId('rs-');

    return retry(
      async (attempt: number) => {
        params.headers!['X-Request-Id'] = generateId('req-');
        params.headers!['X-Retry-Attempt'] = String(attempt);

        const request = new Request(url, params);

        const response = await fetch(request);

        if (!response.ok) {
          throw new HttpError(request, response);
        }

        return response;
      },
      { isRetryable, label: `HTTP ${params.method ?? 'GET'} ${url}` },
    );
  }
}

function isRetryable(error: Error): boolean {
  return error instanceof HttpError && error.response.status >= 500;
}

/**
 * Generates a base32 ID with the given prefix as the ID discriminator.
 * The prefix is useful when reading or grepping thru logs to identify the type
 * of the ID (i.e. it's visually clear that strings that start with `req-` are
 * request IDs).
 */
function generateId(prefix: string) {
  // Base32 alphabet without any ambiguous characters.
  // (details: https://github.com/maksverver/key-encoding#eliminating-ambiguous-characters)
  const alphabet = '23456789abcdefghjklmnpqrstuvwxyz';

  const chars = [prefix];

  for (let i = 0; i < 10; i++) {
    chars.push(alphabet[Math.floor(Math.random() * alphabet.length)]);
  }

  return chars.join('');
}
