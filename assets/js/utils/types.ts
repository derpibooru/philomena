/**
 * Upcast the given value to a `Record<string, V>`. This is needed in a case
 * like the following:
 *
 * ```ts
 * const obj = { mare: "Rainbowshine" };
 *
 * const someKey: string = "mrae";
 *
 * // Here the compiler throws the following error:
 * // > No index signature with a parameter of type 'string' was found on type
 * // > '{ mare: string; }'
 * const value = obj[someKey];
 * ```
 *
 * Here we want to explicitly use the `obj` as a map-like object, so we need to
 * upcast it to a `Record<string, V>`. Doing it with `obj as Record<string, V>`
 * is unsafe, because `as` operator allows not only for safe upcasts but also
 * for unsafe downcasts. This function is intentionally more limited than `as`
 * to make this usage pattern safer, plus you don't need to explicitly spell the
 * `Record<string, V>` type - the target type of the upcast is inferred
 * automatically. So the code higher will look like this:
 *
 * ```ts
 * const value = asRecord(obj)[someKey];
 * ```
 */
export function asRecord<V>(value: Record<string, V>): Record<string, V> {
  return value;
}
