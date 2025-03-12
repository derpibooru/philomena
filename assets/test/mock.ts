export function mockDateNow(initialDateNow: number): void {
  beforeAll(() => {
    vi.useFakeTimers().setSystemTime(initialDateNow);
  });

  afterAll(() => {
    vi.useRealTimers();
  });
}

/**
 * Mocks `Math.random` to return a static value.
 */
export function mockRandom(staticValue = 0.5) {
  const realRandom = Math.random;
  beforeEach(() => (Math.random = () => staticValue));
  afterEach(() => (Math.random = realRandom));
}
