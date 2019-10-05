/**
 * Tags Misc
 */

import { $$ } from './utils/dom';
import store from './utils/store';
import { initTagDropdown} from './tags';
import { setupTagsInput, reloadTagsInput } from './tagsinput';

function tagInputButtons({target}) {
  const actions = {
    save(tagInput) {
      store.set('tag_input', tagInput.value);
    },
    load(tagInput) {
      // If entry 'tag_input' does not exist, try to use the current list
      tagInput.value = store.get('tag_input') || tagInput.value;
      reloadTagsInput(tagInput);
    },
    clear(tagInput) {
      tagInput.value = '';
      reloadTagsInput(tagInput);
    },
  };

  for (const action in actions) {
    if (target.matches(`#tagsinput-${action}`)) actions[action](document.getElementById('image_tag_input'));
  }
}

function setupTags() {
  $$('.js-tag-block').forEach(el => {
    setupTagsInput(el);
    el.classList.remove('js-tag-block');
  });
}

function updateTagSauce({target, detail}) {
  const tagSauce = document.querySelector('.js-tagsauce');

  if (target.matches('#tags-form')) {
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
