export function mockDateNow(initialDateNow: number): void {
  beforeAll(() => {
    vi.useFakeTimers().setSystemTime(initialDateNow);
  });

  afterAll(() => {
    vi.useRealTimers();
  });
}
