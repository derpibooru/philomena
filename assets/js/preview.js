/**
 * Markdown previews (posts, comments, messages)
 */

import { fetchJson } from './utils/requests';
import { filterNode } from './imagesclientside';
import { debounce } from './utils/events.js';
import { hideEl, showEl } from './utils/dom.js';

function handleError(response) {
  const errorMessage = '<div>Preview failed to load!</div>';

  if (!response.ok) {
    return errorMessage;
  }

  return response.text();
}

function commentReply(user, url, textarea, quote) {
  const text = `"@${user}":${url}`;
  let newval = textarea.value;

  if (newval && /\n$/.test(newval)) newval += '\n';
  newval += `${text}\n`;

  if (quote) {
    newval += `[bq="${user.replace('"', '\'')}"] ${quote} [/bq]\n`;
  }

  textarea.value = newval;
  textarea.selectionStart = textarea.selectionEnd = newval.length;

  const writeTabToggle = document.querySelector('a[data-click-tab="write"]:not(.selected)');
  if (writeTabToggle) writeTabToggle.click();

  textarea.focus();
}

/**
 * Stores the abort controller for the current preview request
 * @type {null|AbortController}
 */
let previewAbortController = null;

function getPreview(body, anonymous, previewLoading, previewContent) {
  const path = '/posts/preview';

  if (typeof body !== 'string') return;

  const trimmedBody = body.trim();
  if (trimmedBody.length < 1) {
    previewContent.innerHTML = '';
    return;
  }

  showEl(previewLoading);

  // Abort previous requests if it exists
  if (previewAbortController) previewAbortController.abort();
  previewAbortController = new AbortController();

  fetchJson('POST', path, { body, anonymous }, previewAbortController.signal)
    .then(handleError)
    .then(data => {
      previewContent.innerHTML = data;
      filterNode(previewContent);
      showEl(previewContent);
      hideEl(previewLoading);
    })
    .finally(() => {
      previewAbortController = null;
    });
}

/**
 * Resizes the event target <textarea> to match the size of its contained text, between set
 * minimum and maximum height values. Former comes from CSS, latter is hard coded below.
 * @template {{ target: HTMLTextAreaElement }} E
 * @param {E} e
 */
function resizeTextarea(e) {
  // Reset inline height for fresh calculations
  e.target.style.height = '';
  const { borderTopWidth, borderBottomWidth, height } = window.getComputedStyle(e.target);
  // Add scrollHeight and borders (because border-box) to get the target size that avoids scrollbars
  const contentHeight = e.target.scrollHeight + parseFloat(borderTopWidth) + parseFloat(borderBottomWidth);
  // Get the original default height provided by page styles
  const regularHeight = parseFloat(height);
  // Limit textarea's size to between the original height and 1000px
  const newHeight = Math.max(regularHeight, Math.min(1000, contentHeight));
  e.target.style.height = `${newHeight}px`;
}

function setupPreviews() {
  let textarea = document.querySelector('.js-preview-input');

  if (!textarea) {
    textarea = document.querySelector('.js-preview-description');
  }

  const previewLoading = document.querySelector('.communication-preview__loading');
  const previewContent = document.querySelector('.communication-preview__content');
  const previewAnon = document.querySelector('.js-preview-anonymous') || false;

  if (!textarea || !previewContent) {
    return;
  }

  const updatePreview = () => {
    getPreview(textarea.value, previewAnon && previewAnon.checked, previewLoading, previewContent);
  };

  const debouncedUpdater = debounce(500, () => {
    if (previewContent.previewedText === textarea.value) return;
    previewContent.previewedText = textarea.value;

    updatePreview();
  });

  textarea.addEventListener('keydown', debouncedUpdater);
  textarea.addEventListener('focus', debouncedUpdater);
  textarea.addEventListener('change', resizeTextarea);
  textarea.addEventListener('keyup', resizeTextarea);

  // Fire handler if textarea contains text on page load (e.g. editing)
  if (textarea.value) textarea.dispatchEvent(new Event('keydown'));

  previewAnon && previewAnon.addEventListener('click', updatePreview);

  document.addEventListener('click', event => {
    if (event.target && event.target.closest('.post-reply')) {
      const link = event.target.closest('.post-reply');
      commentReply(link.dataset.author, link.getAttribute('href'), textarea, link.dataset.post);
      event.preventDefault();
    }
  });
}

export { setupPreviews };
