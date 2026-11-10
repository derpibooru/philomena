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

export function assertString(value: unknown): string {
  if (typeof value === 'string') {
    return value;
  }

  throw new Error('Expected string value');
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type Constructor<T> = new (...args: any[]) => T;

function throwTypeError<T>(value: unknown, constructor: Constructor<T>): never {
  const actualConstructor = value instanceof Object ? value.constructor : null;

  let message = `Expected value of type ${constructor.name}`;

  if (actualConstructor) {
    message += `, but got ${actualConstructor.name}`;
  }

  console.error(`${message}`, value);

  throw new Error(message);
}

export function assertType<T>(value: unknown, constructor: Constructor<T>): T {
  if (value instanceof constructor) {
    return value;
  }

  throwTypeError(value, constructor);
}

export function assertNullableType<T>(value: unknown, constructor: Constructor<T>): T | null {
  if (value === null || value instanceof constructor) {
    return value;
  }

  throwTypeError(value, constructor);
}
