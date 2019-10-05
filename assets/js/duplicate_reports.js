/**
 * Interactive behavior for duplicate reports.
 */

import { $, $$ } from './utils/dom';

function setupDupeReports() {
  const [ onion, slider ] = $$('.onion-skin__image, .onion-skin__slider');
  const swipe = $('.swipe__image');

  if (swipe) setupSwipe(swipe);
  if (onion) setupOnionSkin(onion, slider);
}

function setupSwipe(swipe) {
  const [ clip, divider ] = $$('#clip rect, #divider', swipe);
  const { width } = swipe.viewBox.baseVal;

  function moveDivider({ clientX }) {
    // Move center to cursor
    const rect = swipe.getBoundingClientRect();
    const newX = (clientX - rect.left) * (width / rect.width);

    divider.setAttribute('x', newX);
    clip.setAttribute('width', newX);
  }

  swipe.addEventListener('mousemove', moveDivider);
}

function setupOnionSkin(onion, slider) {
  const target = $('#target', onion);

  function setOpacity() {
    target.setAttribute('opacity', slider.value);
  }

  setOpacity();
  slider.addEventListener('input', setOpacity);
}

export { setupDupeReports };
