import { inputDuplicatorCreator } from './input-duplicator';

function pollOptionCreator() {
  inputDuplicatorCreator({
    addButtonSelector: '.js-poll-add-option',
    fieldSelector: '.js-poll-option',
    maxInputCountSelector: '.js-max-option-count',
    removeButtonSelector: '.js-option-remove',
  });
}

export { pollOptionCreator };
