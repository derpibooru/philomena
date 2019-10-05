/**
 * Keyboard shortcuts
 */

function getHover() {
  const thumbBoxHover = document.querySelector('.media-box:hover');
  if (thumbBoxHover) return thumbBoxHover.dataset.imageId;
}

function click(selector) {
  const el = document.querySelector(selector);
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
