export interface DebouncedCacheParams {
  /**
   * Time in milliseconds to wait before calling the function.
   */
  thresholdMs?: number;
}

/**
 * Wraps a function, caches its results and debounces calls to it.
 *
 * *Debouncing* means that if the function is called multiple times within
 * the `thresholdMs` interval, then every new call resets the timer
 * and only the last call to the function will be executed after the timer
 * reaches the `thresholdMs` value. Also, in-progress operation
 * will be aborted, however, the result will still be cached, only the
 * result processing callback will not be called.
 *
 * See more details about the concept of debouncing here:
 * https://lodash.com/docs/4.17.15#debounce.
 *
 *
 * If the function is called with the arguments that were already cached,
 * then the cached result will be returned immediately and the previous
 * scheduled call will be cancelled.
 */
export class DebouncedCache<Params, R> {
  private thresholdMs: number;
  private cache = new Map<string, Promise<R>>();
  private func: (params: Params) => Promise<R>;

  private lastSchedule?: {
    timeout?: ReturnType<typeof setTimeout>;
    abortController: AbortController;
  };

  constructor(func: (params: Params) => Promise<R>, params?: DebouncedCacheParams) {
    this.thresholdMs = params?.thresholdMs ?? 300;
    this.func = func;
  }

  /**
   * Schedules a call to the wrapped function, that will take place only after
   * a `thresholdMs` delay given no new calls to `schedule` are made within that
   * time frame. If they are made, than the scheduled call will be canceled.
   */
  schedule(params: Params, onResult: (result: R) => void): void {
    this.abortLastSchedule(`[DebouncedCache] A new call to '${this.func.name}' was scheduled`);

    const abortController = new AbortController();
    const abortSignal = abortController.signal;
    const key = JSON.stringify(params);

    if (this.cache.has(key)) {
      this.subscribe(this.cache.get(key)!, abortSignal, onResult);
      this.lastSchedule = { abortController };
      return;
    }

    const afterTimeout = () => {
      // This can't be triggered via the public API of this class, because we cancel
      // the setTimeout call when abort is triggered, but it's here just in case
      /* v8 ignore start */
      if (this.shouldAbort(abortSignal)) {
        return;
      }
      /* v8 ignore end */

      // In theory, we could pass the abort signal to the function, but we don't
      // do that and let the function run even if it was aborted, and then cache
      // its result. This works well under the assumption that the function isn't
      // too expensive to run (like a quick GET request), so aborting it in the
      // middle wouldn't save too much resources. If needed, we can make this
      // behavior configurable in the future.
      const promise = this.func.call(null, params);

      // We don't remove an entry from the cache if the promise is rejected.
      // We expect that the underlying function will handle the errors and
      // do the retries internally if necessary.
      this.cache.set(key, promise);

      this.subscribe(promise, abortSignal, onResult);
    };

    this.lastSchedule = {
      timeout: setTimeout(afterTimeout, this.thresholdMs),
      abortController,
    };
  }

  private shouldAbort(abortSignal: AbortSignal) {
    if (abortSignal.aborted) {
      console.debug(`A call was aborted after the debounce threshold was reached`, abortSignal.reason);
    }
    return abortSignal.aborted;
  }

  private async subscribe(promise: Promise<R>, abortSignal: AbortSignal, onResult: (result: R) => void): Promise<void> {
    if (this.shouldAbort(abortSignal)) {
      return;
    }

    let result;
    try {
      result = await promise;
    } catch (error) {
      console.error(`An error occurred while calling '${this.func.name}'.`, error);
      return;
    }

    if (this.shouldAbort(abortSignal)) {
      return;
    }

    try {
      onResult(result);
    } catch (error) {
      console.error(`An error occurred while processing the result of '${this.func.name}'.`, error);
    }
  }

  abortLastSchedule(reason: string): void {
    if (!this.lastSchedule) {
      return;
    }

    clearTimeout(this.lastSchedule.timeout);
    this.lastSchedule.abortController.abort(new DOMException(reason, 'AbortError'));
  }
}
