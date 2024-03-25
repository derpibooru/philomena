import { inputDuplicatorCreator } from './input-duplicator';

function setupInputs() {
  inputDuplicatorCreator({
    addButtonSelector: '.js-image-add-source',
    fieldSelector: '.js-image-source',
    maxInputCountSelector: '.js-max-source-count',
    removeButtonSelector: '.js-source-remove',
  });
}

function imageSourcesCreator() {
  setupInputs();
  document.addEventListener('fetchcomplete', ({ target, detail }) => {
    const sourceSauce = document.querySelector('.js-sourcesauce');

    if (target.matches('#source-form')) {
      detail.text().then(text => {
        sourceSauce.outerHTML = text;
        setupInputs();
      });
    }
  });
}

export { imageSourcesCreator };
