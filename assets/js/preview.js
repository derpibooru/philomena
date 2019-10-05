/**
 * Textile previews (posts, comments, messages)
 */

import { fetchJson } from './utils/requests';
import { filterNode } from './imagesclientside';

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

function getPreview(body, anonymous, previewTab, isImage = false) {
  let path = '/posts/preview';

  if (isImage) path = '/images/preview';

  fetchJson('POST', path, { body, anonymous })
    .then(handleError)
    .then(data => {
      previewTab.innerHTML = data;
      filterNode(previewTab);
    });
}

function setupPreviews() {
  let textarea = document.querySelector('.js-preview-input');
  let imageDesc = false;

  if (!textarea) {
    textarea = document.querySelector('.js-preview-description');
    imageDesc = true;
  }

  const previewButton = document.querySelector('a[data-click-tab="preview"]');
  const previewTab = document.querySelector('.block__tab[data-tab="preview"]');
  const previewAnon = document.querySelector('.preview-anonymous') || false;

  if (!textarea || !previewButton) {
    return;
  }

  previewButton.addEventListener('click', () => {
    if (previewTab.previewedText === textarea.value) return;
    previewTab.previewedText = textarea.value;

    getPreview(textarea.value, Boolean(previewAnon.checked), previewTab, imageDesc);
  });

  previewAnon && previewAnon.addEventListener('click', () => {
    getPreview(textarea.value, Boolean(previewAnon.checked), previewTab, imageDesc);
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
