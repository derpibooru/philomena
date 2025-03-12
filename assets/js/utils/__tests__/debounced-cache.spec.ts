import { DebouncedCache } from '../debounced-cache';

describe('DebouncedCache', () => {
  beforeAll(() => {
    vi.useFakeTimers();
  });

  const consoleSpy = {
    debug: vi.spyOn(console, 'debug'),
    error: vi.spyOn(console, 'error'),
  };

  afterEach(() => {
    consoleSpy.debug.mockClear();
    consoleSpy.error.mockClear();
  });

  it('should call the function after a debounce threshold and cache the result', async () => {
    const { producer, cache } = createTestCache();

    const consumer = vi.fn();

    cache.schedule({ a: 1, b: 2 }, consumer);
    await vi.runAllTimersAsync();

    expect(producer).toHaveBeenCalledWith({ a: 1, b: 2 });
    expect(consumer).toHaveBeenCalledWith(3);

    cache.schedule({ a: 1, b: 2 }, consumer);
    await vi.runAllTimersAsync();

    expect(producer).toHaveBeenCalledTimes(1);
    expect(consumer).toHaveBeenCalledTimes(2);

    expect(consoleSpy.debug).not.toHaveBeenCalled();
    expect(consoleSpy.error).not.toHaveBeenCalled();
  });

  describe('should abort the last scheduled call when a new one is scheduled', () => {
    test('scheduling before the debounce threshold is reached', async () => {
      const { producer, cache } = createTestCache();

      const consumer1 = vi.fn();
      const consumer2 = vi.fn();

      cache.schedule({ a: 1, b: 2 }, consumer1);
      cache.schedule({ a: 1, b: 2 }, consumer2);
      await vi.runAllTimersAsync();

      expect(consumer1).not.toHaveBeenCalled();
      expect(consumer2).toHaveBeenCalledWith(3);
      expect(producer).toHaveBeenCalledOnce();

      // No logs should be emitted because the `setTimeout` call itself should have been aborted.
      expect(consoleSpy.debug.mock.calls).toMatchInlineSnapshot(`[]`);
      expect(consoleSpy.error.mock.calls).toMatchInlineSnapshot(`[]`);
    });

    test('scheduling after the debounce threshold is reached', async () => {
      const threshold = 300;
      const { producer, cache } = createTestCache(threshold);

      const consumer1 = vi.fn();
      const consumer2 = vi.fn();

      cache.schedule({ a: 1, b: 2 }, consumer1);
      vi.advanceTimersByTime(threshold);

      cache.schedule({ a: 1, b: 2 }, consumer2);
      await vi.runAllTimersAsync();

      expect(consumer1).not.toHaveBeenCalled();
      expect(consumer2).toHaveBeenCalledWith(3);
      expect(producer).toHaveBeenCalledOnce();

      expect(consoleSpy.debug.mock.calls).toMatchInlineSnapshot(`
        [
          [
            "A call was aborted after the debounce threshold was reached",
            DOMException {},
          ],
        ]
      `);
      expect(consoleSpy.error.mock.calls).toMatchInlineSnapshot(`[]`);
    });
  });

  describe('should handle errors by logging them', () => {
    test('error in producer', async () => {
      const producer = vi.fn(() => Promise.reject(new Error('producer error')));
      const cache = new DebouncedCache(producer);

      const consumer = vi.fn();

      cache.schedule(undefined, consumer);
      await vi.runAllTimersAsync();

      expect(consumer).not.toHaveBeenCalled();

      expect(consoleSpy.debug).not.toHaveBeenCalled();
      expect(consoleSpy.error.mock.calls).toMatchInlineSnapshot(`
        [
          [
            "An error occurred while calling 'spy'.",
            [Error: producer error],
          ],
        ]
      `);
    });

    test('error in consumer', async () => {
      const { producer, cache } = createTestCache();

      const consumer = vi.fn(() => {
        throw new Error('consumer error');
      });

      cache.schedule({ a: 1, b: 2 }, consumer);
      await vi.runAllTimersAsync();

      expect(producer).toHaveBeenCalledOnce();

      expect(consoleSpy.debug).not.toHaveBeenCalled();
      expect(consoleSpy.error.mock.calls).toMatchInlineSnapshot(`
          [
            [
              "An error occurred while processing the result of 'producerImpl'.",
              [Error: consumer error],
            ],
          ]
        `);
    });
  });
});

function createTestCache(thresholdMs?: number) {
  const producer = vi.fn(producerImpl);
  const cache = new DebouncedCache(producer, { thresholdMs });

  return { producer, cache };
}

interface ProducerParams {
  a: number;
  b: number;
}

async function producerImpl(params: ProducerParams): Promise<number> {
  return params.a + params.b;
}
