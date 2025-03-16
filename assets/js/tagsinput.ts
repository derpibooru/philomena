/**
 * Fancy tag editor.
 */

import { assertNotNull, assertType } from './utils/assert';
import { $, $$, clearEl, removeEl, showEl, hideEl, escapeCss, escapeHtml } from './utils/dom';

export function setupTagsInput(tagBlock: HTMLDivElement) {
  const form = assertNotNull(tagBlock.closest('form'));
  const textarea = assertNotNull($<HTMLTextAreaElement>('.js-taginput-plain', tagBlock));
  const container = assertNotNull($<HTMLDivElement>('.js-taginput-fancy', tagBlock));
  const parentField = assertNotNull(tagBlock.parentElement);
  const setup = assertNotNull($<HTMLButtonElement>('.js-tag-block ~ button', parentField));
  const inputField = assertNotNull($<HTMLInputElement>('input', container));
  const submitButton = assertNotNull($<HTMLInputElement | HTMLButtonElement>('[type="submit"]', form));

  let tags: string[] = [];

  // Load in the current tag set from the textarea
  setup.addEventListener('click', importTags);

  // Respond to tags being added
  textarea.addEventListener('addtag', handleAddTag);

  // Respond to reload event
  textarea.addEventListener('reload', importTags);

  // Respond to [x] clicks in the tag editor
  tagBlock.addEventListener('click', handleTagClear);

  // Respond to key sequences in the input field
  inputField.addEventListener('keydown', handleKeyEvent);

  // Respond to autocomplete form clicks
  inputField.addEventListener('autocomplete', handleAutocomplete as EventListener);

  // Respond to Ctrl+Enter shortcut
  tagBlock.addEventListener('keydown', handleCtrlEnter);

  // TODO: Cleanup this bug fix
  // Switch to fancy tagging if user settings want it
  if (fancyEditorRequested(tagBlock)) {
    showEl($$<HTMLElement>('.js-taginput-fancy'));
    showEl($$<HTMLElement>('.js-taginput-hide'));
    hideEl($$<HTMLElement>('.js-taginput-plain'));
    hideEl($$<HTMLElement>('.js-taginput-show'));
    importTags();
  }

  function handleAutocomplete(event: CustomEvent<string>) {
    insertTag(event.detail);
    inputField.focus();
  }

  function handleAddTag(event: AddtagEvent) {
    // Ignore if not in tag edit mode
    if (container.classList.contains('hidden')) return;

    insertTag(event.detail.name);
    event.stopPropagation();
  }

  function handleTagClear(event: Event) {
    const target = assertType(event.target, HTMLElement);

    if (target.dataset.tagName) {
      event.preventDefault();
      removeTag(target.dataset.tagName, assertNotNull(target.parentElement));
    }
  }

  function handleKeyEvent(event: KeyboardEvent) {
    const { keyCode, ctrlKey, shiftKey } = event;

    // allow form submission with ctrl+enter if no text was typed
    if (keyCode === 13 && ctrlKey && inputField.value === '') {
      return;
    }

    // backspace on a blank input field
    if (keyCode === 8 && inputField.value === '') {
      event.preventDefault();
      const erased = $<HTMLElement>('.tag:last-of-type', container);

      if (erased) removeTag(tags[tags.length - 1], erased);
    }

    // enter or comma
    if (keyCode === 13 || (keyCode === 188 && !shiftKey)) {
      event.preventDefault();
      inputField.value.split(',').forEach(t => insertTag(t));
      inputField.value = '';
    }
  }

  function handleCtrlEnter(event: KeyboardEvent) {
    const { keyCode, ctrlKey } = event;
    if (keyCode !== 13 || !ctrlKey) return;

    submitButton.click();
  }

  function insertTag(name: string) {
    name = name.trim(); // eslint-disable-line no-param-reassign

    // Add if not degenerate or already present
    if (name.length === 0 || tags.indexOf(name) !== -1) return;

    // Remove instead if the tag name starts with a minus
    if (name[0] === '-') {
      name = name.slice(1); // eslint-disable-line no-param-reassign
      const tagLink = assertNotNull($(`[data-tag-name="${escapeCss(name)}"]`, container));

      removeTag(name, assertNotNull(tagLink.parentElement));
      inputField.value = '';

      return;
    }

    tags.push(name);
    textarea.value = tags.join(', ');

    // Insert the new element
    const el = `<span class="tag">${escapeHtml(name)} <a href="#" data-click-focus=".js-taginput-input" data-tag-name="${escapeHtml(name)}">x</a></span>`;
    inputField.insertAdjacentHTML('beforebegin', el);
    inputField.value = '';
  }

  function removeTag(name: string, element: HTMLElement) {
    removeEl(element);

    // Remove the tag from the list
    tags.splice(tags.indexOf(name), 1);
    textarea.value = tags.join(', ');
  }

  function importTags() {
    clearEl(container);
    container.appendChild(inputField);

    tags = [];
    textarea.value.split(',').forEach(t => insertTag(t));
    textarea.value = tags.join(', ');
  }
}

function fancyEditorRequested(tagBlock: HTMLDivElement) {
  // Check whether the user made the fancy editor the default for each type of tag block.
  return (
    (window.booru.fancyTagUpload && tagBlock.classList.contains('fancy-tag-upload')) ||
    (window.booru.fancyTagEdit && tagBlock.classList.contains('fancy-tag-edit'))
  );
}

export function setupTagListener() {
  document.addEventListener('addtag', event => {
    if (event.target.value) event.target.value += ', ';
    event.target.value += event.detail.name;
  });
}

export function addTag(textarea: HTMLInputElement | HTMLTextAreaElement, name: string) {
  textarea.dispatchEvent(new CustomEvent('addtag', { detail: { name }, bubbles: true }));
}

export function reloadTagsInput(textarea: HTMLInputElement | HTMLTextAreaElement) {
  textarea.dispatchEvent(new CustomEvent('reload'));
}
