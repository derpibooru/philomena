export {};

/**
 * This is a place where we augment the core standard library types for any
 * important and documented reasons.
 */
declare global {
  interface ObjectConstructor {
    /**
     * A slightly more narrow overload of `Object.fromEntries` that captures
     * the type of keys in the input iterable.
     *
     * Compare this standard declaration:
     *
     * ```ts
     * interface ObjectConstructor {
     *   fromEntries<T = any>(entries: Iterable<readonly [PropertyKey, T]>): { [k: string]: T; };
     * }
     * ```
     *
     * where the returned object always has the index signature `[k: string]`, while
     * this overload preserves the exact type of the first element of the tuple
     * as the key type instead, which makes the following code compile:
     *
     *```ts
     * const keys = ["a", "b"] as const;
     * const bruh: { a: number, b: number } = Object.fromEntries(keys.map(key => [key, 1]));
     * ```
     */
    fromEntries<E extends readonly [PropertyKey, unknown]>(entries: Iterable<E>): Record<E[0], E[1]>;

    /**
     * This augmentation disables the following unsafe overload:
     *
     * ```ts
     * interface ObjectConstructor {
     *     // ...
     *     fromEntries(entries: Iterable<readonly any[]>): any;
     * }
     * ```
     *
     * Why is this bad? Because it's an extremely sneaky footgun in code like
     * the following:
     *
     * ```ts
     * const object = { mare: "Rainbowshine" };
     * const entries = Object.entries(object).map(([key, value]) => {
     *     // Do smth with `key` and `value` here, or just return them as is
     *     return [key, value]
     * });
     *
     * const bruh: { no: "type", ckeching: "at all" } = Object.fromEntries(entries);
     * ```
     * You may be surprised, but the code higher comples just fine without any
     * even slightest warnings from `tsc` or `eslint`.
     *
     * The problem here is that the type of `[key, value]` in the `return`
     * statement is implicitly widened to `(K | V)[]` instead of keeping it as a
     * tuple `[K, V]`. This triggers the `any` overload of `Object.fromEntries`.
     *
     * This has already caused a few bugs on @MareStare's experience, so this
     * solution was invented where we augment `fromEntries` with the `unknown`
     * catch-all overload which triggers a compiler error in code like higher
     * urging one to use `[key, value] as const` to prevent array-to-tuple
     * widening.
     */
    fromEntries(entries: Iterable<readonly unknown[]>): unknown;
  }
}
