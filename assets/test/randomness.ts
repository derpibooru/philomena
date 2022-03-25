/**
 * @fileOverview Utilities to aid in unit testing where multiple potential values need to be considered.
 *               Picking from a pool of limited data randomly can add further resilience.
 */

/**
 * Randomly returns either `true` or `false`
 */
export const getRandomBoolean = (): boolean => Math.random() > 0.5;

/**
 * Returns a random integer between `min` and `max`, inclusive
 */
export function getRandomIntBetween(min: number, max: number): number {
  const intMin = Math.ceil(min);
  const intMax = Math.floor(max);
  return Math.floor(Math.random() * (intMax - intMin + 1) + intMin);
}

/**
 * Returns a random item from the provided `array`, throws an error if `array is empty
 */
export const getRandomArrayItem = <T>(array: T[]): T => {
  if (array.length === 0) throw new Error('Attempt to pick random item from empty array');

  return array[Math.floor(Math.random() * array.length)];
};
