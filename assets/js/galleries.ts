/**
 * Gallery rearrangement.
 */

import { arraysEqual } from './utils/array';
import { assertNotNull, assertNotUndefined } from './utils/assert';
import { $, $$ } from './utils/dom';
import { initDraggables } from './utils/draggable';
import { fetchJson } from './utils/requests';

export function setupGalleryEditing() {
  if (!$('.rearrange-button')) return;

  const [rearrangeEl, saveEl] = $$<HTMLElement>('.rearrange-button');
  const sortableEl = assertNotNull($<HTMLDivElement>('#sortable'));
  const containerEl = assertNotNull($<HTMLDivElement>('.js-resizable-media-container'));

  // Copy array
  const galleryImages = assertNotUndefined(window.booru.galleryImages);
  let oldImages = galleryImages.slice();
  let newImages = galleryImages.slice();

  initDraggables();

  for (const mediaBox of $$<HTMLDivElement>('.media-box', containerEl)) {
    mediaBox.draggable = true;
  }

  rearrangeEl.addEventListener('click', () => {
    sortableEl.classList.add('editing');
    containerEl.classList.add('drag-container');
  });

  saveEl.addEventListener('click', () => {
    sortableEl.classList.remove('editing');
    containerEl.classList.remove('drag-container');

    newImages = $$<HTMLDivElement>('.image-container', containerEl).map(i =>
      parseInt(assertNotUndefined(i.dataset.imageId), 10),
    );

    // If nothing changed, don't bother.
    if (arraysEqual(newImages, oldImages)) return;

    const reorderPath = assertNotUndefined(saveEl.dataset.reorderPath);

    fetchJson('PATCH', reorderPath, {
      image_ids: newImages,
    }).then(() => {
      // copy the array again so that we have the newly updated set
      oldImages = newImages.slice();
    });
  });
}
