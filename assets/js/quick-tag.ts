/**
 * Quick Tag
 */

import store from './utils/store';
import { assertNotNull, assertNotUndefined } from './utils/assert';
import { $, $$, toggleEl } from './utils/dom';
import { fetchJson, handleError } from './utils/requests';
import { delegate, leftClick } from './utils/events';

const imageQueueStorage = 'quickTagQueue';
const currentTagStorage = 'quickTagName';

function currentQueue(): string[] {
  return store.get<string[]>(imageQueueStorage) || [];
}

function currentTags(): string {
  return store.get<string>(currentTagStorage) || '';
}

function setTagButton(text: string) {
  assertNotNull($('.js-quick-tag--submit span')).textContent = text;
}

function toggleActiveState() {
  toggleEl($$<HTMLElement>('.js-quick-tag,.js-quick-tag--abort,.js-quick-tag--all,.js-quick-tag--submit'));

  setTagButton(`Submit (${currentTags()})`);

  $$('.media-box__header').forEach(el => el.classList.toggle('media-box__header--unselected'));
  $$('.media-box__header').forEach(el => el.classList.remove('media-box__header--selected'));

  currentQueue().forEach(id =>
    $$(`.media-box__header[data-image-id="${id}"]`).forEach(el => el.classList.add('media-box__header--selected')),
  );
}

function activate(event: Event) {
  event.preventDefault();

  store.set(currentTagStorage, window.prompt('A comma-delimited list of tags you want to add:'));

  if (currentTags()) {
    toggleActiveState();
  }
}

function reset() {
  store.remove(currentTagStorage);
  store.remove(imageQueueStorage);

  toggleActiveState();
}

function promptReset(event: Event) {
  event.preventDefault();

  if (window.confirm('Are you sure you want to abort batch tagging?')) {
    reset();
  }
}

function submit(event: Event) {
  event.preventDefault();

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

function modifyImageQueue(event: Event, mediaBox: HTMLDivElement) {
  if (!currentTags()) {
    return;
  }

  const imageId = assertNotUndefined(mediaBox.dataset.imageId);
  const queue = currentQueue();
  const isSelected = queue.includes(imageId);

  if (isSelected) {
    queue.splice(queue.indexOf(imageId), 1);
  } else {
    queue.push(imageId);
  }

  for (const boxHeader of $$(`.media-box__header[data-image-id="${imageId}"]`)) {
    boxHeader.classList.toggle('media-box__header--selected');
  }

  store.set(imageQueueStorage, queue);
  event.preventDefault();
}

function toggleAllImages(event: Event, _target: Element) {
  for (const mediaBox of $$<HTMLDivElement>('#imagelist-container .media-box')) {
    modifyImageQueue(event, mediaBox);
  }
}

delegate(document, 'click', {
  '.js-quick-tag': leftClick(activate),
  '.js-quick-tag--abort': leftClick(promptReset),
  '.js-quick-tag--submit': leftClick(submit),
  '.js-quick-tag--all': leftClick(toggleAllImages),
  '.media-box': leftClick(modifyImageQueue),
});

export function setupQuickTag() {
  const tagButton = $<HTMLAnchorElement>('.js-quick-tag');
  if (tagButton && currentTags()) {
    toggleActiveState();
  }
}
