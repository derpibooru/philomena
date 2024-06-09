/**
 * Keyboard shortcuts
 */

import { $ } from './utils/dom';

interface ShortcutKeycodes {
  [key: string]: () => void
}

function getHover(): string | null {
  const thumbBoxHover = $<HTMLDivElement>('.media-box:hover');

  return thumbBoxHover && (thumbBoxHover.dataset.imageId || null);
}

function openFullView() {
  const imageHover = $<HTMLDivElement>('[data-uris]:hover');

  if (!imageHover || !imageHover.dataset.uris) return;

  window.location = JSON.parse(imageHover.dataset.uris).full;
}

function openFullViewNewTab() {
  const imageHover = $<HTMLDivElement>('[data-uris]:hover');

  if (!imageHover || !imageHover.dataset.uris) return;

  window.open(JSON.parse(imageHover.dataset.uris).full);
}

function click(selector: string) {
  const el = $<HTMLElement>(selector);

  if (el) {
    el.click();
  }
}

function isOK(event: KeyboardEvent): boolean {
  return !event.altKey && !event.ctrlKey && !event.metaKey &&
         document.activeElement !== null &&
         document.activeElement.tagName !== 'INPUT' &&
         document.activeElement.tagName !== 'TEXTAREA';
}

const keyCodes: ShortcutKeycodes = {
  KeyJ() { click('.js-prev'); },             // J - go to previous image
  KeyI() { click('.js-up'); },               // I - go to index page
  KeyK() { click('.js-next'); },             // K - go to next image
  KeyR() { click('.js-rand'); },             // R - go to random image
  KeyS() { click('.js-source-link'); },      // S - go to image source
  KeyL() { click('.js-tag-sauce-toggle'); }, // L - edit tags
  KeyO() { openFullView(); },                // O - open original
  KeyV() { openFullViewNewTab(); },          // V - open original in a new tab
  KeyF() {                                   // F - favourite image
    getHover() ? click(`a.interaction--fave[data-image-id="${getHover()}"]`)
      : click('.block__header a.interaction--fave');
  },
  KeyU() {                                   // U - upvote image
    getHover() ? click(`a.interaction--upvote[data-image-id="${getHover()}"]`)
      : click('.block__header a.interaction--upvote');
  },
};

export function listenForKeys() {
  document.addEventListener('keydown', (event: KeyboardEvent) => {
    if (isOK(event) && keyCodes[event.code]) {
      keyCodes[event.code]();
      event.preventDefault();
    }
  });
}
