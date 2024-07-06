/**
 * FP version 4
 *
 * Not reliant on deprecated properties, and potentially
 * more accurate at what it's supposed to do.
 */

import store from './utils/store';

const storageKey = 'cached_ses_value';

declare global {
  interface Keyboard {
    getLayoutMap: () => Promise<Map<string, string>>;
  }

  interface UserAgentData {
    brands: [{ brand: string; version: string }];
    mobile: boolean;
    platform: string;
  }

  interface Navigator {
    deviceMemory: number | undefined;
    keyboard: Keyboard | undefined;
    userAgentData: UserAgentData | undefined;
  }
}

/**
 * Creates a 53-bit non-cryptographic hash of a string.
 *
 * @param str The string to hash.
 * @param seed The seed to use for hash generation.
 * @return The resulting hash as a 53-bit number.
 * @see {@link https://stackoverflow.com/a/52171480}
 */
function cyrb53(str: string, seed: number = 0x16fe7b0a): number {
  let h1 = 0xdeadbeef ^ seed;
  let h2 = 0x41c6ce57 ^ seed;

  for (let i = 0, ch; i < str.length; i++) {
    ch = str.charCodeAt(i);
    h1 = Math.imul(h1 ^ ch, 2654435761);
    h2 = Math.imul(h2 ^ ch, 1597334677);
  }

  h1 = Math.imul(h1 ^ (h1 >>> 16), 2246822507);
  h1 ^= Math.imul(h2 ^ (h2 >>> 13), 3266489909);
  h2 = Math.imul(h2 ^ (h2 >>> 16), 2246822507);
  h2 ^= Math.imul(h1 ^ (h1 >>> 13), 3266489909);

  return 4294967296 * (2097151 & h2) + (h1 >>> 0);
}

/**
 * Get keyboard layout data from the navigator layout map.
 *
 * @return String containing layout map entries, or `none` when unavailable
 */
async function getKeyboardData(): Promise<string> {
  if (navigator.keyboard) {
    const layoutMap = await navigator.keyboard.getLayoutMap();

    return Array.from(layoutMap.entries())
      .sort()
      .map(([k, v]) => `${k}${v}`)
      .join('');
  }

  return 'none';
}

/**
 * Get an approximation of memory available in gigabytes.
 *
 * @return String containing device memory data, or `1` when unavailable
 */
function getMemoryData(): string {
  if (navigator.deviceMemory) {
    return navigator.deviceMemory.toString();
  }

  return '1';
}

/**
 * Get the "brands" of the user agent.
 *
 * For Chromium-based browsers this returns additional data like "Edge" or "Chrome"
 * which may also contain additional data beyond the `userAgent` property.
 *
 * @return String containing brand data, or `none` when unavailable
 */
function getUserAgentBrands(): string {
  const data = navigator.userAgentData;

  if (data) {
    let brands = 'none';

    if (data.brands && data.brands.length > 0) {
      // NB: Chromium implements GREASE protocol to prevent ossification of
      // the "Not a brand" string - see https://stackoverflow.com/a/64443187
      brands = data.brands
        .filter(e => !e.brand.match(/.*ot.*rand.*/gi))
        .map(e => `${e.brand}${e.version}`)
        .sort()
        .join('');
    }

    return `${brands}${data.mobile}${data.platform}`;
  }

  return 'none';
}

/**
 * Get the size in rems of the default body font.
 *
 * Causes a forced layout. Be sure to cache this value.
 *
 * @return String with the rem size
 */
function getFontRemSize(): string {
  const testElement = document.createElement('span');
  testElement.style.minWidth = '1rem';
  testElement.style.maxWidth = '1rem';
  testElement.style.position = 'absolute';

  document.body.appendChild(testElement);

  const width = testElement.clientWidth.toString();

  document.body.removeChild(testElement);

  return width;
}

/**
 * Create a semi-unique string from browser attributes.
 *
 * @return Hexadecimally encoded 53 bit number padded to 7 bytes.
 */
async function createFp(): Promise<string> {
  const prints: string[] = [
    navigator.userAgent,
    navigator.hardwareConcurrency.toString(),
    navigator.maxTouchPoints.toString(),
    navigator.language,
    await getKeyboardData(),
    getMemoryData(),
    getUserAgentBrands(),
    getFontRemSize(),

    screen.height.toString(),
    screen.width.toString(),
    screen.colorDepth.toString(),
    screen.pixelDepth.toString(),

    window.devicePixelRatio.toString(),
    new Date().getTimezoneOffset().toString(),
  ];

  return cyrb53(prints.join('')).toString(16).padStart(14, '0');
}

/**
 * Gets the existing `_ses` value from local storage or cookies.
 *
 * @return String `_ses` value or `null`
 */
function getSesValue(): string | null {
  // Try storage
  const storageValue: string | null = store.get(storageKey);
  if (storageValue) {
    return storageValue;
  }

  // Try cookie
  const match = document.cookie.match(/_ses=([a-f0-9]+)/);
  if (match && match[1]) {
    return match[1];
  }

  // Not found
  return null;
}

/**
 * Sets the `_ses` cookie.
 *
 * If `cached_ses_value` is present in local storage, uses it to set the `_ses` cookie.
 * Otherwise, if the `_ses` cookie already exists, uses its value instead.
 * Otherwise, attempts to generate a new value for the `_ses` cookie based on
 * various browser attributes.
 * Failing all previous methods, sets the `_ses` cookie to a fallback value.
 */
export async function setSesCookie() {
  let sesValue = getSesValue();

  if (!sesValue || sesValue.charAt(0) !== 'd' || sesValue.length !== 15) {
    // The prepended 'd' acts as a crude versioning mechanism.
    sesValue = `d${await createFp()}`;
    store.set(storageKey, sesValue);
  }

  document.cookie = `_ses=${sesValue}; path=/; SameSite=Lax`;
}
