import { inputDuplicatorCreator } from './input-duplicator';

function imageSourcesCreator() {
  inputDuplicatorCreator({
    addButtonSelector: '.js-image-add-source',
    fieldSelector: '.js-image-source',
    maxInputCountSelector: '.js-max-source-count',
    removeButtonSelector: '.js-source-remove',
  });
}

export { imageSourcesCreator };
