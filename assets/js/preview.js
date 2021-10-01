/**
 * Markdown previews (posts, comments, messages)
 */

import { fetchJson } from './utils/requests';
import { filterNode } from './imagesclientside';
import { hideEl, showEl } from './utils/dom.js';

function handleError(response) {
  const errorMessage = '<div>Preview failed to load!</div>';

  if (!response.ok) {
    return errorMessage;
  }

  return response.text();
}

function commentReply(user, url, textarea, quote) {
  const text = `[${user}](${url})`;
  let newval = textarea.value;

  if (newval && /\n$/.test(newval)) newval += '\n';
  newval += `${text}\n`;

  if (quote) {
    newval += `> ${quote.replace(/\n/g, '\n> ')}\n\n`;
  }

  textarea.value = newval;
  textarea.selectionStart = textarea.selectionEnd = newval.length;

  const writeTabToggle = document.querySelector('a[data-click-tab="write"]:not(.selected)');
  if (writeTabToggle) writeTabToggle.click();

  textarea.focus();
}

function getPreview(body, anonymous, previewLoading, previewIdle, previewContent) {
  const path = '/posts/preview';

  if (typeof body !== 'string') return;

  showEl(previewLoading);
  hideEl(previewIdle);

  fetchJson('POST', path, { body, anonymous })
    .then(handleError)
    .then(data => {
      previewContent.innerHTML = data;
      filterNode(previewContent);
      showEl(previewIdle);
      hideEl(previewLoading);
    });
}

/**
 * Resizes the event target <textarea> to match the size of its contained text, between set
 * minimum and maximum height values. Former comes from CSS, latter is hard coded below.
 * @template {{ target: HTMLTextAreaElement }} E
 * @param {E} e
 */
function resizeTextarea(e) {
  const { borderTopWidth, borderBottomWidth, height } = window.getComputedStyle(e.target);
  // Add scrollHeight and borders (because border-box) to get the target size that avoids scrollbars
  const contentHeight = e.target.scrollHeight + parseFloat(borderTopWidth) + parseFloat(borderBottomWidth);
  // Get the original default height provided by page styles
  const currentHeight = parseFloat(height);
  // Limit textarea's size to between the original height and 1000px
  const newHeight = Math.max(currentHeight, Math.min(1000, contentHeight));
  e.target.style.height = `${newHeight}px`;
}

function setupPreviews() {
  let textarea = document.querySelector('.js-preview-input');

  if (!textarea) {
    textarea = document.querySelector('.js-preview-description');
  }

  const previewButton = document.querySelector('a[data-click-tab="preview"]');
  const previewLoading = document.querySelector('.js-preview-loading');
  const previewIdle = document.querySelector('.js-preview-idle');
  const previewContent = document.querySelector('.js-preview-content');
  const previewAnon = document.querySelector('.js-preview-anonymous') || false;

  if (!textarea || !previewContent) {
    return;
  }

  const getCacheKey = () => {
    return (previewAnon && previewAnon.checked ? 'anon;' : '') + textarea.value;
  }

  const previewedTextAttribute = 'data-previewed-text';
  const updatePreview = () => {
    const cachedValue = getCacheKey()
    if (previewContent.getAttribute(previewedTextAttribute) === cachedValue) return;
    previewContent.setAttribute(previewedTextAttribute, cachedValue);

    getPreview(textarea.value, previewAnon && previewAnon.checked, previewLoading, previewIdle, previewContent);
  };

  previewButton.addEventListener('click', updatePreview);
  textarea.addEventListener('change', resizeTextarea);
  textarea.addEventListener('keyup', resizeTextarea);

  // Fire handler for automatic resizing if textarea contains text on page load (e.g. editing)
  if (textarea.value) textarea.dispatchEvent(new Event('change'));

  previewAnon && previewAnon.addEventListener('click', () => {
    if (previewContent.classList.contains('hidden')) return;

    updatePreview();
  });

  document.addEventListener('click', event => {
    if (event.target && event.target.closest('.post-reply')) {
      const link = event.target.closest('.post-reply');
      commentReply(link.dataset.author, link.getAttribute('href'), textarea, link.dataset.post);
      event.preventDefault();
    }
  });
}

export { setupPreviews };
