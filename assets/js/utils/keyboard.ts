import { asRecord } from './types';

/**
 * Even though `keyCode` is deprecated, it is still the most reliable way to
 * detect the key pressed. So this object maps the `keyCode` numeric value to a
 * more readable string representation.
 */
const keysMapping = {
  8: 'Backspace',
  // Covers the numpad enter too
  13: 'Enter',
  27: 'Escape',
  // Covers numpad arrows too
  37: 'ArrowLeft',
  38: 'ArrowUp',
  39: 'ArrowRight',
  40: 'ArrowDown',
  65: 'KeyA',
  66: 'KeyB',
  67: 'KeyC',
  68: 'KeyD',
  69: 'KeyE',
  70: 'KeyF',
  71: 'KeyG',
  72: 'KeyH',
  73: 'KeyI',
  74: 'KeyJ',
  75: 'KeyK',
  76: 'KeyL',
  77: 'KeyM',
  78: 'KeyN',
  79: 'KeyO',
  80: 'KeyP',
  81: 'KeyQ',
  82: 'KeyR',
  83: 'KeyS',
  84: 'KeyT',
  85: 'KeyU',
  86: 'KeyV',
  87: 'KeyW',
  88: 'KeyX',
  89: 'KeyY',
  90: 'KeyZ',
  188: 'Comma',
} as const;

/**
 * A map of known keys to be used in code to avoid typos.
 */
export const keys = Object.fromEntries(Object.values(keysMapping).map(key => [key, key]));

/**
 * There are many inconsistencies in the way different browsers handle keyboard
 * events. This function is a heroic attempt to normalize them.
 *
 * There are the following nuances discovered so far:
 * - Chrome & Firefox on Android devices return empty `code` when "Enter" is
 *   pressed via the virtual keyboard.
 * - There seems to be no way to reliably detect the `,` key on virtual
 *   keyboards on phones.
 * - The `event.code` uses `NumpadEnter` for the numpad enter key on regular
 *   keyboards
 */
export function normalizedKeyboardKey(event: KeyboardEvent): string {
  // It is possible that this chain goes all the way to the `event.key` because
  // on mobile phones the `Enter` key has empty `code` for some reason, but it
  // has `Enter` as `key`.
  return asRecord(keysMapping)[event.keyCode] || event.code || event.key;
}
