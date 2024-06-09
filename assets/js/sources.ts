import { assertNotNull } from './utils/assert';
import { $ } from './utils/dom';
import { inputDuplicatorCreator } from './input-duplicator';
import '../types/ujs';

function setupInputs() {
  inputDuplicatorCreator({
    addButtonSelector: '.js-image-add-source',
    fieldSelector: '.js-image-source',
    maxInputCountSelector: '.js-max-source-count',
    removeButtonSelector: '.js-source-remove',
  });
}

export function imageSourcesCreator() {
  setupInputs();

  document.addEventListener('fetchcomplete', ({ target, detail }) => {
    if (target.matches('#source-form')) {
      const sourceSauce = assertNotNull($<HTMLElement>('.js-sourcesauce'));

      detail.text().then(text => {
        sourceSauce.outerHTML = text;
        setupInputs();
      });
    }
  });
}
