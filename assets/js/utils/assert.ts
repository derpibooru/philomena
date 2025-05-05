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

export function assertType<T>(value: unknown, constructor: new (...args: unknown[]) => T): T {
  if (value instanceof constructor) {
    return value;
  }

  const actualConstructor = value instanceof Object ? value.constructor : null;

  let message = `Expected value of type ${constructor.name}`;

  if (actualConstructor) {
    message += `, but got ${actualConstructor.name}`;
  }

  console.error(`${message}`, value);

  throw new Error(message);
}
