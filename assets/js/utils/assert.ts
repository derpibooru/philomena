export function assertNotNull<T>(value: T | null): T {
  if (value === null) {
    throw new Error('Expected non-null value');
  }

  return value;
}

export function assertNotUndefined<T>(value: T | undefined): T {
  if (value === undefined) {
    throw new Error('Expected non-undefined value');
  }

  return value;
}

/* eslint-disable @typescript-eslint/no-explicit-any */
type Constructor<T> = { new (...args: any[]): T };

export function assertType<T>(value: any, c: Constructor<T>): T {
  if (value instanceof c) {
    return value;
  }

  throw new Error('Expected value of type');
}
/* eslint-enable @typescript-eslint/no-explicit-any */
