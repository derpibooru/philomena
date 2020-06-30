/**
 * Fancy tag editor.
 */

import { $, $$, clearEl, removeEl, showEl, hideEl, escapeHtml } from './utils/dom';

function setupTagsInput(tagBlock) {
  const [ textarea, container ] = $$('.js-taginput', tagBlock);
  const setup = $('.js-tag-block ~ button', tagBlock.parentNode);
  const inputField = $('input', container);
  const uploadButton = $('.js-upload-submit');
  const uploadButtonPresent = uploadButton !== null;
  const tagsTextareaPlain = $('.js-taginput-plain');

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

  // TODO: Cleanup this bug fix
  // Switch to fancy tagging if user settings want it
  if (fancyEditorRequested(tagBlock)) {
    showEl($$('.js-taginput-fancy'));
    showEl($$('.js-taginput-hide'));
    hideEl($$('.js-taginput-plain'));
    hideEl($$('.js-taginput-show'));
    importTags();
  }

  const ratingsTags = ['safe', 'suggestive', 'questionable', 'explicit', 'semi-grimdark', 'grimdark', 'grotesque'];
  const checks = {numTags: false, ratingIncluded: false};

  //TODO handle this better?
  const errorsDisplayed = {numTags: false, ratingIncluded: false};

  //chosing to pull from the plain editor field, even if fancy editor
  //  is being displayed currently. This ensures the most current tags
  //  will be pulled, in either case. This isn't using the tags[]
  //  object, because it won't be up-to-date if the plain editor is being used
  function tagsValid() {
    const tagsArr = tagsTextareaPlain.value.split(',');
    const len = tagsArr.length;

    if (len >= 3) {
      checks.numTags = true;
      //return false;
    }
    else {
      checks.numTags = false;
    }

    //TODO is there a more efficient way to check this?
    const intersection = tagsArr.filter(tag => {
      return ratingsTags.indexOf(tag.trim()) > -1;
    });
    if (intersection.length > 0) {
      checks.ratingIncluded = true;
    }
    else {
      checks.ratingIncluded = false;
    }

    return checks.numTags === true && checks.ratingIncluded === true;
  }

  if (uploadButtonPresent) {
    uploadButton.addEventListener('click', event => {
      if (tagsValid() === false) {
        //prevent the upload button from submitting the form
        event.preventDefault();

        //set timer to re-enable the upload submit button
        setTimeout(() => {
          uploadButton.textContent = 'Upload';
          uploadButton.disabled = false;
        }, 1000);

        //"Save" button under the tagsinput textarea
        const siblingElement = $('#tagsinput-save');

        //insert error message
        if (checks.numTags === false) {
          if (errorsDisplayed.numTags === false) {
            const newSpan = document.createElement('SPAN');
            newSpan.className = 'help-block';
            newSpan.innerHTML = 'Tag input must contain at least 3 tags';
            siblingElement.insertAdjacentElement('beforebegin', newSpan);
            errorsDisplayed.numTags = true;
          }
        }

        //insert error message
        if (checks.ratingIncluded === false) {
          if (errorsDisplayed.ratingIncluded === false) {
            const newSpan = document.createElement('SPAN');
            newSpan.className = 'help-block';
            newSpan.innerHTML = 'Tag input must contain at least one rating tag';
            siblingElement.insertAdjacentElement('beforebegin', newSpan);
            errorsDisplayed.ratingIncluded = true;
          }
        }

        //TODO add some sort of scrolling or focus change, to make sure the tags errors
        //  are in view?
      }
    });
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
    const { keyCode, ctrlKey } = event;

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
    if (keyCode === 13 || keyCode === 188) {
      event.preventDefault();
      inputField.value.split(',').forEach(t => insertTag(t));
      inputField.value = '';
    }

  }

  function insertTag(name) {
    name = name.trim(); // eslint-disable-line no-param-reassign

    // Add if not degenerate or already present
    if (name.length === 0 || tags.indexOf(name) !== -1) return;
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
