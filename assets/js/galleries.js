/**
 * Gallery rearrangement.
 */

import { arraysEqual } from './utils/array';
import { $, $$ } from './utils/dom';
import { initDraggables } from './utils/draggable';
import { fetchJson } from './utils/requests';

export function setupGalleryEditing() {
  if (!$('.rearrange-button')) return;

  const [ rearrangeEl, saveEl ] = $$('.rearrange-button');
  const sortableEl = $('#sortable');
  const containerEl = $('.js-resizable-media-container');

  // Copy array
  let oldImages = window.booru.galleryImages.slice();
  let newImages = window.booru.galleryImages.slice();

  initDraggables();

  $$('.media-box', containerEl).forEach(i => i.draggable = true);

  rearrangeEl.addEventListener('click', () => {
    sortableEl.classList.add('editing');
    containerEl.classList.add('drag-container');
  });

  saveEl.addEventListener('click', () => {
    sortableEl.classList.remove('editing');
    containerEl.classList.remove('drag-container');

    newImages = $$('.image-container', containerEl).map(i => parseInt(i.dataset.imageId, 10));

    // If nothing changed, don't bother.
    if (arraysEqual(newImages, oldImages)) return;

    fetchJson('PATCH', saveEl.dataset.reorderPath, {
      image_ids: newImages,

    // copy the array again so that we have the newly updated set
    }).then(() => oldImages = newImages.slice());
  });
}
