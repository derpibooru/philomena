export interface RetryParams {
  /**
   * Maximum number of attempts to retry the operation. The first attempt counts
   * too, so setting this to 1 is equivalent to no retries.
   */
  maxAttempts?: number;

  /**
   * Initial delay for the first retry. Subsequent retries will be exponentially
   * delayed up to `maxDelayMs`.
   */
  minDelayMs?: number;

  /**
   * Max value a delay can reach. This is useful to avoid unreasonably long
   * delays that can be reached at a larger number of retries where the delay
   * grows exponentially very fast.
   */
  maxDelayMs?: number;

  /**
   * If present determines if the error should be retried or immediately re-thrown.
   * All errors that aren't instances of `Error` are considered non-retryable.
   */
  isRetryable?(error: Error): boolean;

  /**
   * Human-readable message to identify the operation being retried. By default
   * the function name is used.
   */
  label?: string;
}

export type RetryFunc<R = void> = (attempt: number, nextDelayMs?: number) => Promise<R>;

/**
 * Retry an async operation with exponential backoff and jitter.
 *
 * The callback receives the current attempt number and the delay before the
 * next attempt in case the current attempt fails. The next delay may be
 * `undefined` if this is the last attempt and no further retries will be scheduled.
 *
 * This is based on the following AWS paper:
 * https://aws.amazon.com/blogs/architecture/exponential-backoff-and-jitter/
 */
export async function retry<R>(func: RetryFunc<R>, params?: RetryParams): Promise<R> {
  const maxAttempts = params?.maxAttempts ?? 3;

  if (maxAttempts < 1) {
    throw new Error(`Invalid 'maxAttempts' for retry: ${maxAttempts}`);
  }

  const minDelayMs = params?.minDelayMs ?? 200;

  if (minDelayMs < 0) {
    throw new Error(`Invalid 'minDelayMs' for retry: ${minDelayMs}`);
  }

  const maxDelayMs = params?.maxDelayMs ?? 1500;

  if (maxDelayMs < minDelayMs) {
    throw new Error(`Invalid 'maxDelayMs' for retry: ${maxDelayMs}, 'minDelayMs' is ${minDelayMs}`);
  }

  const label = params?.label || func.name || '{unnamed routine}';

  const backoffExponent = 2;

  let attempt = 1;
  let nextDelayMs = minDelayMs;

  while (true) {
    const hasNextAttempts = attempt < maxAttempts;

    try {
      // XXX: an `await` is important in this block to make sure the exception is caught
      // in this scope. Doing a `return func()` would be a big mistake, so don't try
      // to "refactor" that!
      const result = await func(attempt, hasNextAttempts ? nextDelayMs : undefined);
      return result;
    } catch (error) {
      if (!(error instanceof Error) || (params?.isRetryable && !params.isRetryable(error))) {
        throw error;
      }

      if (!hasNextAttempts) {
        console.error(`All ${maxAttempts} attempts of running ${label} failed`, error);
        throw error;
      }

      console.warn(
        `[Attempt ${attempt}/${maxAttempts}] Error when running ${label}. Retrying in ${nextDelayMs} milliseconds...`,
        error,
      );

      await sleep(nextDelayMs);

      // Equal jitter algorithm taken from AWS blog post's code reference:
      // https://github.com/aws-samples/aws-arch-backoff-simulator/blob/66cb169277051eea207dbef8c7f71767fe6af144/src/backoff_simulator.py#L35-L38
      let pure = minDelayMs * backoffExponent ** attempt;

      // Make sure we don't overflow
      pure = Math.min(maxDelayMs, pure);

      // Now that we have a purely exponential delay, we add random jitter
      // to avoid DDOSing the backend from multiple clients retrying at
      // the same time (see the "thundering herd problem" on Wikipedia).
      const halfPure = pure / 2;
      nextDelayMs = halfPure + randomBetween(0, halfPure);

      // Make sure we don't underflow
      nextDelayMs = Math.max(minDelayMs, nextDelayMs);

      attempt += 1;
    }
  }
}

function randomBetween(min: number, max: number): number {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}
