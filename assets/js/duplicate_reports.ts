/**
 * Interactive behavior for duplicate reports.
 */

import { assertNotNull } from './utils/assert';
import { $, $$ } from './utils/dom';

export function setupDupeReports() {
  const onion = $<SVGSVGElement>('.onion-skin__image');
  const slider = $<HTMLInputElement>('.onion-skin__slider');
  const swipe = $<SVGSVGElement>('.swipe__image');

  if (swipe) setupSwipe(swipe);
  if (onion && slider) setupOnionSkin(onion, slider);
}

function setupSwipe(swipe: SVGSVGElement) {
  const [clip, divider] = $$<SVGRectElement>('#clip rect, #divider', swipe);
  const { width } = swipe.viewBox.baseVal;

  function moveDivider({ clientX }: MouseEvent) {
    // Move center to cursor
    const rect = swipe.getBoundingClientRect();
    const newX = (clientX - rect.left) * (width / rect.width);

    divider.setAttribute('x', newX.toString());
    clip.setAttribute('width', newX.toString());
  }

  swipe.addEventListener('mousemove', moveDivider);
}

function setupOnionSkin(onion: SVGSVGElement, slider: HTMLInputElement) {
  const target = assertNotNull($<SVGImageElement>('#target', onion));

  function setOpacity() {
    target.setAttribute('opacity', slider.value);
  }

  setOpacity();
  slider.addEventListener('input', setOpacity);
}
