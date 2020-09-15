/**
 * Quick Tag
 */

import store from './utils/store';
import { $, $$, toggleEl, onLeftClick } from './utils/dom';
import { fetchJson, handleError } from './utils/requests';

const imageQueueStorage = 'quickTagQueue';
const currentTagStorage = 'quickTagName';

function currentQueue() { return store.get(imageQueueStorage) || []; }

function currentTags() { return store.get(currentTagStorage) || ''; }

function getTagButton() { return $('.js-quick-tag'); }

function setTagButton(text) { $('.js-quick-tag--submit span').textContent = text; }

function toggleActiveState() {

  toggleEl($('.js-quick-tag'),
    $('.js-quick-tag--abort'),
    $('.js-quick-tag--all'),
    $('.js-quick-tag--submit'));

  setTagButton(`Submit (${currentTags()})`);

  $$('.media-box__header').forEach(el => el.classList.toggle('media-box__header--unselected'));
  $$('.media-box__header').forEach(el => el.classList.remove('media-box__header--selected'));
  currentQueue().forEach(id => $$(`.media-box__header[data-image-id="${id}"]`).forEach(el => el.classList.add('media-box__header--selected')));

}

function activate() {

  store.set(currentTagStorage, window.prompt('A comma-delimited list of tags you want to add:'));

  if (currentTags()) toggleActiveState();

}

function reset() {

  store.remove(currentTagStorage);
  store.remove(imageQueueStorage);

  toggleActiveState();

}

function submit() {

  setTagButton(`Wait... (${currentTags()})`);

  fetchJson('PUT', '/admin/batch/tags', {
    tags: currentTags(),
    image_ids: currentQueue(),
  })
    .then(handleError)
    .then(r => r.json())
    .then(data => {

      if (data.failed.length) window.alert(`Failed to add tags to the images with these IDs: ${data.failed}`);

      reset();

    });

}

function modifyImageQueue(mediaBox) {

  if (currentTags()) {
    const imageId    = mediaBox.dataset.imageId,
          queue      = currentQueue(),
          isSelected = queue.includes(imageId);

    isSelected ? queue.splice(queue.indexOf(imageId), 1)
      : queue.push(imageId);

    $$(`.media-box__header[data-image-id="${imageId}"]`).forEach(el => el.classList.toggle('media-box__header--selected'));

    store.set(imageQueueStorage, queue);
  }

}

function toggleAllImages() {
  $$('#imagelist-container .media-box').forEach(modifyImageQueue);
}

function clickHandler(event) {

  const targets = {
    '.js-quick-tag': activate,
    '.js-quick-tag--abort': reset,
    '.js-quick-tag--submit': submit,
    '.js-quick-tag--all': toggleAllImages,
    '.media-box': modifyImageQueue,
  };

  for (const target in targets) {
    if (event.target && event.target.closest(target)) {
      targets[target](event.target.closest(target));
      currentTags() && event.preventDefault();
    }
  }

}

function setupQuickTag() {

  if (getTagButton() && currentTags()) toggleActiveState();
  if (getTagButton()) onLeftClick(clickHandler);

}

export { setupQuickTag };
