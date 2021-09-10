/**
 * Fancy tag editor.
 */

import { $, $$, clearEl, removeEl, showEl, hideEl, escapeCss, escapeHtml } from './utils/dom';

function setupTagsInput(tagBlock) {
  const [ textarea, container ] = $$('.js-taginput', tagBlock);
  const setup = $('.js-tag-block ~ button', tagBlock.parentNode);
  const inputField = $('input', container);

  let tags = [];

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
  inputField.addEventListener('autocomplete', handleAutocomplete);

  // Respond to Ctrl+Enter shortcut
  tagBlock.addEventListener('keydown', handleCtrlEnter);

  // TODO: Cleanup this bug fix
  // Switch to fancy tagging if user settings want it
  if (fancyEditorRequested(tagBlock)) {
    showEl($$('.js-taginput-fancy'));
    showEl($$('.js-taginput-hide'));
    hideEl($$('.js-taginput-plain'));
    hideEl($$('.js-taginput-show'));
    importTags();
  }


  function handleAutocomplete(event) {
    insertTag(event.detail.value);
    inputField.focus();
  }

  function handleAddTag(event) {
    // Ignore if not in tag edit mode
    if (container.classList.contains('hidden')) return;

    insertTag(event.detail.name);
    event.stopPropagation();
  }

  function handleTagClear(event) {
    if (event.target.dataset.tagName) {
      event.preventDefault();
      removeTag(event.target.dataset.tagName, event.target.parentNode);
    }
  }

  function handleKeyEvent(event) {
    const { keyCode, ctrlKey, shiftKey } = event;

    // allow form submission with ctrl+enter if no text was typed
    if (keyCode === 13 && ctrlKey && inputField.value === '') {
      return;
    }

    // backspace on a blank input field
    if (keyCode === 8 && inputField.value === '') {
      event.preventDefault();
      const erased = $('.tag:last-of-type', container);

      if (erased) removeTag(tags[tags.length - 1], erased);
    }

    // enter or comma
    if (keyCode === 13 || (keyCode === 188 && !shiftKey)) {
      event.preventDefault();
      inputField.value.split(',').forEach(t => insertTag(t));
      inputField.value = '';
    }

  }

  function handleCtrlEnter(event) {
    const { keyCode, ctrlKey } = event;
    if (keyCode !== 13 || !ctrlKey) return;

    $('[type="submit"]', tagBlock.closest('form')).click();
  }

  function insertTag(name) {
    name = name.trim(); // eslint-disable-line no-param-reassign

    // Add if not degenerate or already present
    if (name.length === 0 || tags.indexOf(name) !== -1) return;

    // Remove instead if the tag name starts with a minus
    if (name[0] === "-") {
      name = name.slice(1); // eslint-disable-line no-param-reassign
      const tagLink = $(`[data-tag-name="${escapeCss(name)}"]`, container);

      return removeTag(name, tagLink.parentNode);
    }

    tags.push(name);
    textarea.value = tags.join(', ');

    // Insert the new element
    const el = `<span class="tag">${escapeHtml(name)} <a href="#" data-click-focus=".js-taginput-input" data-tag-name="${escapeHtml(name)}">x</a></span>`;
    inputField.insertAdjacentHTML('beforebegin', el);
    inputField.value = '';
  }

  function removeTag(name, element) {
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

function fancyEditorRequested(tagBlock) {
  // Check whether the user made the fancy editor the default for each type of tag block.
  return window.booru.fancyTagUpload && tagBlock.classList.contains('fancy-tag-upload') ||
         window.booru.fancyTagEdit   && tagBlock.classList.contains('fancy-tag-edit');
}

function setupTagListener() {
  document.addEventListener('addtag', event => {
    if (event.target.value) event.target.value += ', ';
    event.target.value += event.detail.name;
  });
}

function addTag(textarea, name) {
  textarea.dispatchEvent(new CustomEvent('addtag', { detail: { name }, bubbles: true }));
}

function reloadTagsInput(textarea) {
  textarea.dispatchEvent(new CustomEvent('reload'));
}

export { setupTagsInput, setupTagListener, addTag, reloadTagsInput };
