import { assertNotNull, assertNotUndefined } from './utils/assert';
import { $, $$, showEl, hideEl } from './utils/dom';
import { delegate, leftClick } from './utils/events';
import { addTag } from './tagsinput';

function focusAndSelectLast(field: HTMLInputElement, characterCount: number) {
  field.focus();
  field.selectionStart = field.value.length - characterCount;
  field.selectionEnd = field.value.length;
}

function prependToLast(field: HTMLInputElement, value: string) {
  // Find the last comma in the input and advance past it
  const separatorIndex = field.value.lastIndexOf(',');
  const advanceBy = field.value[separatorIndex + 1] === ' ' ? 2 : 1;

  // Insert the value string at the new location
  field.value = [
    field.value.slice(0, separatorIndex + advanceBy),
    value,
    field.value.slice(separatorIndex + advanceBy),
  ].join('');
}

function getAssociatedData(target: HTMLElement) {
  const form = assertNotNull(target.closest('form'));
  const input = assertNotNull($<HTMLInputElement>('.js-search-field', form));
  const helpBoxes = $$<HTMLDivElement>('[data-search-help]', form);

  return { input, helpBoxes };
}

function showHelp(helpBoxes: HTMLDivElement[], typeName: string, subject: string) {
  for (const helpBox of helpBoxes) {
    // Get the subject name span
    const subjectName = assertNotNull($<HTMLElement>('.js-search-help-subject', helpBox));

    // Take the appropriate action for this help box
    if (helpBox.dataset.searchHelp === typeName) {
      subjectName.textContent = subject;
      showEl(helpBox);
    } else {
      hideEl(helpBox);
    }
  }
}

function onSearchAdd(_event: Event, target: HTMLAnchorElement) {
  // Load form
  const { input, helpBoxes } = getAssociatedData(target);

  // Get data for this link
  const addValue = assertNotUndefined(target.dataset.searchAdd);
  const showHelpValue = assertNotUndefined(target.dataset.searchShowHelp);
  const selectLastValue = target.dataset.searchSelectLast;

  // Add the tag
  addTag(input, addValue);

  // Show associated help, if available
  showHelp(helpBoxes, showHelpValue, assertNotNull(target.textContent));

  // Select last characters, if requested
  if (selectLastValue) {
    focusAndSelectLast(input, Number(selectLastValue));
  }
}

function onSearchPrepend(_event: Event, target: HTMLAnchorElement) {
  // Load form
  const { input } = getAssociatedData(target);

  // Get data for this link
  const prependValue = assertNotUndefined(target.dataset.searchPrepend);

  // Prepend
  prependToLast(input, prependValue);
}

export function setupSearch() {
  delegate(document, 'click', {
    'form.js-search-form a[data-search-add][data-search-show-help]': leftClick(onSearchAdd),
    'form.js-search-form a[data-search-prepend]': leftClick(onSearchPrepend),
  });
}
