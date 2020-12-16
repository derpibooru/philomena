/**
 * Misc
 */

import store from './utils/store';
import { $, $$ } from './utils/dom';

let touchMoved = false;

function formResult({target, detail}) {

  const elements = {
    '#description-form': '.image-description',
    '#uploader-form': '.image_uploader',
    '#source-form': '#image-source'
  };

  function showResult(resultEl, formEl, response) {
    resultEl.innerHTML = response;
    resultEl.classList.remove('hidden');
    formEl.classList.add('hidden');
    formEl.querySelector('input[type="submit"],button').disabled = false;
  }

  for (const element in elements) {
    if (target.matches(element)) detail.text().then(text => showResult($(elements[element]), target, text));
  }

}

function revealSpoiler(event) {

  const { target } = event;
  const spoiler = target.closest('.spoiler');
  let imgspoiler = target.closest('.spoiler .imgspoiler, .spoiler-revealed .imgspoiler');
  const showContainer = target.closest('.image-show-container');

  // Prevent reveal if touchend came after touchmove event
  if (touchMoved) {
    touchMoved = false;
    return;
  }

  if (spoiler) {
    if (showContainer) {
      const imageShow = showContainer.querySelector('.image-show');
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

function setupEvents() {
  const extrameta = $('#extrameta');

  if (store.get('hide_uploader') && extrameta) extrameta.classList.add('hidden');
  if (store.get('hide_score')) {
    $$('.upvotes,.score,.downvotes').forEach(s => s.classList.add('hidden'));
  }

  document.addEventListener('fetchcomplete', formResult);
  document.addEventListener('click', revealSpoiler);
  document.addEventListener('touchend', revealSpoiler);
  document.addEventListener('touchmove', () => touchMoved = true);
}

export { setupEvents };
