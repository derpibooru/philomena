export function mockDateNow(initialDateNow: number): void {
  beforeAll(() => {
    jest.useFakeTimers().setSystemTime(initialDateNow);
  });

  afterAll(() => {
    jest.useRealTimers();
  });
}
