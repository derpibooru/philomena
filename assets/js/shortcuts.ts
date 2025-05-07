/**
 * Keyboard shortcuts
 */

import { normalizedKeyboardKey, keys } from './utils/keyboard';
import { $ } from './utils/dom';

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
  return (
    !event.altKey &&
    !event.ctrlKey &&
    !event.metaKey &&
    document.activeElement !== null &&
    document.activeElement.tagName !== 'INPUT' &&
    document.activeElement.tagName !== 'TEXTAREA'
  );
}
const actions = {
  // go to previous image
  [keys.KeyJ]: () => click('.js-prev'),

  // go to index page
  [keys.KeyI]: () => click('.js-up'),

  // go to next image
  [keys.KeyK]: () => click('.js-next'),

  // go to random image
  [keys.KeyR]: () => click('.js-rand'),

  // go to image source
  [keys.KeyS]: () => click('.js-source-link'),

  // edit tags
  [keys.KeyL]: () => click('.js-tag-sauce-toggle'),

  // open original
  [keys.KeyO]: () => openFullView(),

  // open original in a new tab
  [keys.KeyV]: () => openFullViewNewTab(),

  // favourite image
  [keys.KeyF]() {
    click(getHover() ? `a.interaction--fave[data-image-id="${getHover()}"]` : '.block__header a.interaction--fave');
  },

  // upvote image
  [keys.KeyU]() {
    click(getHover() ? `a.interaction--upvote[data-image-id="${getHover()}"]` : '.block__header a.interaction--upvote');
  },
};

export function listenForKeys() {
  document.addEventListener('keydown', (event: KeyboardEvent) => {
    const key = normalizedKeyboardKey(event);

    if (isOK(event) && actions[key]) {
      actions[key]();
      event.preventDefault();
    }
  });
}
