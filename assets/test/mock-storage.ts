type MockStorageKeys = 'getItem' | 'setItem' | 'removeItem';

export function mockStorage<Keys extends MockStorageKeys>(options: Pick<Storage, Keys>): { [k in `${Keys}Spy`]: jest.SpyInstance } {
  const getItemSpy = 'getItem' in options ? jest.spyOn(Storage.prototype, 'getItem') : undefined;
  const setItemSpy = 'setItem' in options ? jest.spyOn(Storage.prototype, 'setItem') : undefined;
  const removeItemSpy = 'removeItem' in options ? jest.spyOn(Storage.prototype, 'removeItem') : undefined;

  beforeAll(() => {
    getItemSpy && getItemSpy.mockImplementation((options as Storage).getItem);
    setItemSpy && setItemSpy.mockImplementation((options as Storage).setItem);
    removeItemSpy && removeItemSpy.mockImplementation((options as Storage).removeItem);
  });

  afterEach(() => {
    getItemSpy && getItemSpy.mockClear();
    setItemSpy && setItemSpy.mockClear();
    removeItemSpy && removeItemSpy.mockClear();
  });

  afterAll(() => {
    getItemSpy && getItemSpy.mockRestore();
    setItemSpy && setItemSpy.mockRestore();
    removeItemSpy && removeItemSpy.mockRestore();
  });

  return { getItemSpy, setItemSpy, removeItemSpy } as ReturnType<typeof mockStorage>;
}

type MockStorageImplApi = { [k in `${MockStorageKeys}Spy`]: jest.SpyInstance } & {
  /**
   * Forces the mock storage back to its default (empty) state
   * @param value
   */
  clearStorage: VoidFunction,
  /**
   * Forces the mock storage to be in the specific state provided as the parameter
   * @param value
   */
  setStorageValue: (value: Record<string, string>) => void,
  /**
   * Forces the mock storage to throw an error for the duration of the provided function's execution,
   * or in case a promise is returned by the function, until that promise is resolved.
   */
  forceStorageError: <Args, Return>(func: (...args: Args[]) => Return | Promise<Return>) => void
}

export function mockStorageImpl(): MockStorageImplApi {
  let shouldThrow = false;
  let tempStorage: Record<string, string> = {};
  const mockStorageSpies = mockStorage({
    setItem(key, value) {
      if (shouldThrow) throw new Error('Mock error thrown by mockStorageImpl.setItem');

      tempStorage[key] = String(value);
    },
    getItem(key: string): string | null {
      if (shouldThrow) throw new Error('Mock error thrown by mockStorageImpl.getItem');

      return key in tempStorage ? tempStorage[key] : null;
    },
    removeItem(key: string) {
      if (shouldThrow) throw new Error('Mock error thrown by mockStorageImpl.removeItem');

      delete tempStorage[key];
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
    tempStorage = value;
  };
  const clearStorage = () => setStorageValue({});

  afterEach(() => {
    clearStorage();
  });

  return { ...mockStorageSpies, clearStorage, forceStorageError, setStorageValue };
}
