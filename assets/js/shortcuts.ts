/**
 * Keyboard shortcuts
 */

import { $ } from './utils/dom';

type ShortcutKeyMap = Record<number, () => void>;

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

// prettier-ignore
const keyCodes: ShortcutKeyMap = {
  74() { click('.js-prev');             }, // J - go to previous image
  73() { click('.js-up');               }, // I - go to index page
  75() { click('.js-next');             }, // K - go to next image
  82() { click('.js-rand');             }, // R - go to random image
  83() { click('.js-source-link');      }, // S - go to image source
  76() { click('.js-tag-sauce-toggle'); }, // L - edit tags
  79() { openFullView();                }, // O - open original
  86() { openFullViewNewTab();          }, // V - open original in a new tab
  70() {
    // F - favourite image
    click(getHover() ? `a.interaction--fave[data-image-id="${getHover()}"]` : '.block__header a.interaction--fave');
  },
  85() {
    // U - upvote image
    click(getHover() ? `a.interaction--upvote[data-image-id="${getHover()}"]` : '.block__header a.interaction--upvote');
  },
};

export function listenForKeys() {
  document.addEventListener('keydown', (event: KeyboardEvent) => {
    if (isOK(event) && keyCodes[event.keyCode]) {
      keyCodes[event.keyCode]();
      event.preventDefault();
    }
  });
}
