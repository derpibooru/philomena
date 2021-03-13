/**
 * Keyboard shortcuts
 */

import { $ } from './utils/dom';

function getHover() {
  const thumbBoxHover = $('.media-box:hover');
  if (thumbBoxHover) return thumbBoxHover.dataset.imageId;
}

function openFullView() {
  const imageHover = $('[data-uris]:hover');
  if (!imageHover) return;

  window.location = JSON.parse(imageHover.dataset.uris).full;
}

function openFullViewNewTab() {
  const imageHover = $('[data-uris]:hover');
  if (!imageHover) return;

  window.open(JSON.parse(imageHover.dataset.uris).full);
}

function click(selector) {
  const el = $(selector);
  if (el) el.click();
}

function isOK(event) {
  return !event.altKey && !event.ctrlKey && !event.metaKey &&
         document.activeElement.tagName !== 'INPUT' &&
         document.activeElement.tagName !== 'TEXTAREA';
}

const keyCodes = {
  74() { click('.js-prev'); },             // J - go to previous image
  73() { click('.js-up'); },               // I - go to index page
  75() { click('.js-next'); },             // K - go to next image
  82() { click('.js-rand'); },             // R - go to random image
  83() { click('.js-source-link'); },      // S - go to image source
  76() { click('.js-tag-sauce-toggle'); }, // L - edit tags
  79() { openFullView() },                 // O - open original
  86() { openFullViewNewTab() },           // V - open original in a new tab
  70() {                                   // F - favourite image
    getHover() ? click(`a.interaction--fave[data-image-id="${getHover()}"]`)
      : click('.block__header a.interaction--fave');
  },
  85() {                                   // U - upvote image
    getHover() ? click(`a.interaction--upvote[data-image-id="${getHover()}"]`)
      : click('.block__header a.interaction--upvote');
  },
};

function listenForKeys() {
  document.addEventListener('keydown', event => {
    if (isOK(event) && keyCodes[event.keyCode]) { keyCodes[event.keyCode](); event.preventDefault(); }
  });
}

export { listenForKeys };
