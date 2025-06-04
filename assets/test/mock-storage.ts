import { MockInstance } from 'vitest';

type MockStorageKeys = 'getItem' | 'setItem' | 'removeItem';

export function mockStorage<Keys extends MockStorageKeys>(
  options: Pick<Storage, Keys>,
): Record<`${Keys}Spy`, MockInstance> {
  const getItemSpy = 'getItem' in options ? vi.spyOn(Storage.prototype, 'getItem') : undefined;
  const setItemSpy = 'setItem' in options ? vi.spyOn(Storage.prototype, 'setItem') : undefined;
  const removeItemSpy = 'removeItem' in options ? vi.spyOn(Storage.prototype, 'removeItem') : undefined;

  beforeAll(() => {
    if (getItemSpy) getItemSpy.mockImplementation((options as Storage).getItem);
    if (setItemSpy) setItemSpy.mockImplementation((options as Storage).setItem);
    if (removeItemSpy) removeItemSpy.mockImplementation((options as Storage).removeItem);
  });

  afterEach(() => {
    if (getItemSpy) getItemSpy.mockClear();
    if (setItemSpy) setItemSpy.mockClear();
    if (removeItemSpy) removeItemSpy.mockClear();
  });

  afterAll(() => {
    if (getItemSpy) getItemSpy.mockRestore();
    if (setItemSpy) setItemSpy.mockRestore();
    if (removeItemSpy) removeItemSpy.mockRestore();
  });

  return { getItemSpy, setItemSpy, removeItemSpy } as ReturnType<typeof mockStorage>;
}

type MockStorageImplApi = Record<`${MockStorageKeys}Spy`, MockInstance> & {
  /**
   * Forces the mock storage back to its default (empty) state
   * @param value
   */
  clearStorage: VoidFunction;
  /**
   * Forces the mock storage to be in the specific state provided as the parameter
   * @param value
   */
  setStorageValue: (value: Record<string, string>) => void;
  /**
   * Forces the mock storage to throw an error for the duration of the provided function's execution,
   * or in case a promise is returned by the function, until that promise is resolved.
   */
  forceStorageError: <Args, Return>(func: (...args: Args[]) => Return | Promise<Return>) => void;
};

export function mockStorageImpl(): MockStorageImplApi {
  let shouldThrow = false;
  let tempStorage = new Map<string, string>();
  const mockStorageSpies = mockStorage({
    setItem(key, value) {
      if (shouldThrow) throw new Error('Mock error thrown by mockStorageImpl.setItem');

      tempStorage.set(key, String(value));
    },
    getItem(key: string): string | null {
      if (shouldThrow) throw new Error('Mock error thrown by mockStorageImpl.getItem');

      return tempStorage.get(key) ?? null;
    },
    removeItem(key: string) {
      if (shouldThrow) throw new Error('Mock error thrown by mockStorageImpl.removeItem');

      tempStorage.delete(key);
    },
  });
  const forceStorageError: MockStorageImplApi['forceStorageError'] = func => {
    shouldThrow = true;
    const value = func();
    if (!(value instanceof Promise)) {
      shouldThrow = false;
      return;
    }

    value.then(() => {
      shouldThrow = false;
    });
  };
  const setStorageValue: MockStorageImplApi['setStorageValue'] = value => {
    tempStorage = new Map(Object.entries(value));
  };
  const clearStorage = () => setStorageValue({});

  afterEach(() => {
    clearStorage();
  });

  return { ...mockStorageSpies, clearStorage, forceStorageError, setStorageValue };
}
