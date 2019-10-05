import { $, $$ } from './utils/dom';
import { addTag } from './tagsinput';

function showHelp(subject, type) {
  $$('[data-search-help]').forEach(helpBox => {
    if (helpBox.getAttribute('data-search-help') === type) {
      $('.js-search-help-subject', helpBox).textContent = subject;
      helpBox.classList.remove('hidden');
    }
    else {
      helpBox.classList.add('hidden');
    }
  });
}

function prependToLast(field, value) {
  const separatorIndex = field.value.lastIndexOf(',');
  const advanceBy = field.value[separatorIndex + 1] === ' ' ? 2 : 1;
  field.value = field.value.slice(0, separatorIndex + advanceBy) + value + field.value.slice(separatorIndex + advanceBy);
}

function selectLast(field, characterCount) {
  field.focus();

  field.selectionStart = field.value.length - characterCount;
  field.selectionEnd = field.value.length;
}

function executeFormHelper(e) {
  const searchField = $('.js-search-field');
  const attr = name => e.target.getAttribute(name);

  attr('data-search-add') && addTag(searchField, attr('data-search-add'));
  attr('data-search-show-help') && showHelp(e.target.textContent, attr('data-search-show-help'));
  attr('data-search-select-last') && selectLast(searchField, parseInt(attr('data-search-select-last'), 10));
  attr('data-search-prepend') && prependToLast(searchField, attr('data-search-prepend'));
}

function setupSearch() {
  const form = $('.js-search-form');

  form && form.addEventListener('click', executeFormHelper);
}

export { setupSearch };
