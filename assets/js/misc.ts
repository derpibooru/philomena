/**
 * Misc
 */

import store from './utils/store';
import { $, $$, hideEl, showEl } from './utils/dom';
import { assertNotNull, assertType } from './utils/assert';
import '../types/ujs';

let touchMoved = false;

function formResult({target, detail}: FetchcompleteEvent) {
  const elements: Record<string, string> = {
    '#description-form': '.image-description',
    '#uploader-form': '.image_uploader'
  };

  function showResult(formEl: HTMLFormElement, resultEl: HTMLElement, response: string) {
    resultEl.innerHTML = response;
    hideEl(formEl);
    showEl(resultEl);

    $$<HTMLInputElement | HTMLButtonElement>('input[type="submit"],button', formEl).forEach(button => {
      button.disabled = false;
    });
  }

  for (const [ formSelector, resultSelector ] of Object.entries(elements)) {
    if (target.matches(formSelector)) {
      const form = assertType(target, HTMLFormElement);
      const result = assertNotNull($<HTMLElement>(resultSelector));

      detail.text().then(text => showResult(form, result, text));
    }
  }
}

function revealSpoiler(event: MouseEvent | TouchEvent) {
  const target = assertNotNull(event.target) as HTMLElement;
  const spoiler = target.closest('.spoiler');
  const showContainer = target.closest('.image-show-container');
  let imgspoiler = target.closest('.spoiler .imgspoiler, .spoiler-revealed .imgspoiler');

  // Prevent reveal if touchend came after touchmove event
  if (touchMoved) {
    touchMoved = false;
    return;
  }

  if (spoiler) {
    if (showContainer) {
      const imageShow = assertNotNull(showContainer.querySelector('.image-show'));

      if (!imageShow.classList.contains('hidden') && imageShow.classList.contains('spoiler-pending')) {
        imageShow.classList.remove('spoiler-pending');
        return;
      }
    }

    spoiler.classList.remove('spoiler');
    spoiler.classList.add('spoiler-revealed');
    // Prevent click-through to links on mobile platforms
    if (event.type === 'touchend') event.preventDefault();

    if (!imgspoiler) {
      imgspoiler = spoiler.querySelector('.imgspoiler');
    }
  }

  if (imgspoiler) {
    imgspoiler.classList.remove('imgspoiler');
    imgspoiler.classList.add('imgspoiler-revealed');

    if (event.type === 'touchend' && !event.defaultPrevented) {
      event.preventDefault();
    }
  }
}

export function setupEvents() {
  const extrameta = $<HTMLElement>('#extrameta');

  if (extrameta && store.get('hide_uploader')) {
    hideEl(extrameta);
  }

  if (store.get('hide_score')) {
    $$<HTMLElement>('.upvotes,.score,.downvotes').forEach(s => hideEl(s));
  }

  document.addEventListener('fetchcomplete', formResult);
  document.addEventListener('click', revealSpoiler);
  document.addEventListener('touchend', revealSpoiler);
  document.addEventListener('touchmove', () => touchMoved = true);
}
