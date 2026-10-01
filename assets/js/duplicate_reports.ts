/**
 * Interactive behavior for duplicate reports.
 */

import { assertNotNull } from './utils/assert';
import { $, $$, makeEl } from './utils/dom';
import { normalizedKeyboardKey, keys } from './utils/keyboard';

export function setupDupeReports() {
  const onion = $<SVGSVGElement>('.onion-skin__image');
  const slider = $<HTMLInputElement>('.onion-skin__slider');
  const swipe = $<SVGSVGElement>('.swipe__image');

  if (swipe) setupSwipe(swipe);
  if (onion && slider) setupOnionSkin(onion, slider);

  setupKeyBindings();

  document.addEventListener('fetchcomplete', mergeDuplicateReportTable);
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
  const [sourceButton, targetButton] = $$<HTMLButtonElement>('.onion-skin__button');

  slider.addEventListener('input', setOpacity);

  function setOpacity() {
    target.setAttribute('opacity', slider.value);
  }

  function setSliderAndOpacity(value: number) {
    slider.value = `${value}`;
    setOpacity();
  }

  setOpacity();

  sourceButton.addEventListener('click', () => {
    setSliderAndOpacity(0);
  });
  targetButton.addEventListener('click', () => {
    setSliderAndOpacity(1);
  });
}

function setupKeyBindings() {
  const onionSkinButtons = $$<HTMLButtonElement>('.onion-skin__button');
  if (onionSkinButtons.length !== 2) return;

  const [onionSkinSourceButton, onionSkinTargetButton] = onionSkinButtons;

  const navigationButtons = $$<HTMLButtonElement>('.comparison--navigation__button');
  if (navigationButtons.length !== 5) return;

  const [
    _navigationSourceButton,
    _navigationTargetButton,
    subtractiveDifferenceButton,
    swipeDifferenceButton,
    onionSkinDifferenceButton,
  ] = navigationButtons;

  const actions = {
    [keys.KeyJ]: () => subtractiveDifferenceButton.click(),
    [keys.KeyK]: () => swipeDifferenceButton.click(),
    [keys.KeyL]: () => onionSkinDifferenceButton.click(),
    [keys.Comma]: () => onionSkinSourceButton.click(),
    [keys.Period]: () => onionSkinTargetButton.click(),
  };

  document.addEventListener('keydown', (event: KeyboardEvent) => {
    const key = normalizedKeyboardKey(event);

    if (actions[key]) {
      actions[key]();
    }
  });
}

function mergeDuplicateReportTable({ target, detail }: FetchcompleteEvent) {
  if (!target.matches('.js-duplicate-report')) {
    return;
  }

  const container = makeEl('template');

  detail.text().then(text => {
    container.innerHTML = text;

    for (const child of container.content.children) {
      if (!(child instanceof HTMLElement)) continue;

      for (const updateTarget of document.querySelectorAll(`.${child.className}`)) {
        updateTarget.outerHTML = child.outerHTML;
      }
    }
  });
}
