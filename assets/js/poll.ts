import { inputDuplicatorCreator } from './input-duplicator';

export function pollOptionCreator() {
  inputDuplicatorCreator({
    addButtonSelector: '.js-poll-add-option',
    fieldSelector: '.js-poll-option',
    maxInputCountSelector: '.js-max-option-count',
    removeButtonSelector: '.js-option-remove',
  });
}
