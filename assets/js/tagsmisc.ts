/**
 * Tags Misc
 */

import { assertType, assertNotNull } from './utils/assert';
import { $, $$ } from './utils/dom';
import store from './utils/store';
import { initTagDropdown } from './tags';
import { setupTagsInput, reloadTagsInput } from './tagsinput';
import '../types/ujs';

type TagInputActionFunction = (tagInput: HTMLTextAreaElement) => void;
type TagInputActionList = Record<string, TagInputActionFunction>;

function tagInputButtons(event: MouseEvent) {
  const target = assertType(event.target, Element);

  const actions: TagInputActionList = {
    save(tagInput: HTMLTextAreaElement) {
      store.set('tag_input', tagInput.value);
    },
    load(tagInput: HTMLTextAreaElement) {
      // If entry 'tag_input' does not exist, try to use the current list
      tagInput.value = store.get('tag_input') || tagInput.value;
      reloadTagsInput(tagInput);
    },
    clear(tagInput: HTMLTextAreaElement) {
      tagInput.value = '';
      reloadTagsInput(tagInput);
    },
  };

  for (const [name, action] of Object.entries(actions)) {
    if (target && target.matches(`#tagsinput-${name}`)) {
      action(assertNotNull($<HTMLTextAreaElement>('#image_tag_input')));
    }
  }
}

function setupTags() {
  $$<HTMLDivElement>('.js-tag-block').forEach(el => {
    setupTagsInput(el);
    el.classList.remove('js-tag-block');
  });
}

function updateTagSauce({ target, detail }: FetchcompleteEvent) {
  if (target.matches('#tags-form')) {
    const tagSauce = assertNotNull($<HTMLDivElement>('.js-tagsauce'));

    detail.text().then(text => {
      tagSauce.outerHTML = text;
      setupTags();
      initTagDropdown();
    });
  }
}

function setupTagEvents() {
  setupTags();
  document.addEventListener('fetchcomplete', updateTagSauce);
  document.addEventListener('click', tagInputButtons);
}

export { setupTagEvents };
