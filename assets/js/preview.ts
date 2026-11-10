/**
 * Markdown previews (posts, comments, messages)
 */

import { fetchJson } from './utils/requests';
import { bindImageTarget } from './image-expansion';
import { filterNode } from './imagesclientside';
import { $, hideEl, showEl } from './utils/dom';
import { assertType } from './utils/assert';
import { delegate } from './utils/events';

function handleError(response: Response): Promise<string> | string {
  const errorMessage = '<div>Preview failed to load!</div>';

  if (!response.ok) {
    return errorMessage;
  }

  return response.text();
}

function commentReply(user: string, url: string, textarea: HTMLTextAreaElement, quote?: string) {
  const text = `[${user}](${url})`;
  let newval = textarea.value;

  if (newval && /\n$/.test(newval)) newval += '\n';
  newval += `${text}\n`;

  if (quote) {
    newval += `> ${quote.replace(/\n/g, '\n> ')}\n\n`;
  }

  textarea.value = newval;
  textarea.selectionStart = textarea.selectionEnd = newval.length;

  const writeTabToggle = $<HTMLAnchorElement>('a[data-click-tab="write"]:not(.selected)');
  if (writeTabToggle) writeTabToggle.click();

  textarea.focus();
}

function getPreview(
  body: string,
  anonymous: boolean,
  previewLoading: HTMLElement,
  previewIdle: HTMLElement,
  previewContent: HTMLElement,
) {
  const path = '/posts/preview';

  showEl(previewLoading);
  hideEl(previewIdle);

  fetchJson('POST', path, { body, anonymous })
    .then(handleError)
    .then((data: string) => {
      previewContent.innerHTML = data;
      filterNode(previewContent);
      bindImageTarget(previewContent);
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
function resizeTextarea(e: Event) {
  const target = assertType(e.target, HTMLTextAreaElement);
  const { borderTopWidth, borderBottomWidth, height } = window.getComputedStyle(target);
  // Add scrollHeight and borders (because border-box) to get the target size that avoids scrollbars
  const contentHeight = target.scrollHeight + parseFloat(borderTopWidth) + parseFloat(borderBottomWidth);
  // Get the original default height provided by page styles
  const currentHeight = parseFloat(height);
  // Limit textarea's size to between the original height and 1000px
  const newHeight = Math.max(currentHeight, Math.min(1000, contentHeight));
  target.style.height = `${newHeight}px`;
}

function setupPreviews() {
  let textarea = $<HTMLTextAreaElement>('.js-preview-input');

  if (!textarea) {
    textarea = $<HTMLTextAreaElement>('.js-preview-description');
  }

  const previewButton = $<HTMLAnchorElement>('a[data-click-tab="preview"]');
  const previewLoading = $<HTMLElement>('.js-preview-loading');
  const previewIdle = $<HTMLElement>('.js-preview-idle');
  const previewContent = $<HTMLElement>('.js-preview-content');
  const previewAnon = $<HTMLInputElement>('.js-preview-anonymous');

  if (!textarea || !previewContent || !previewButton || !previewLoading || !previewIdle) {
    return;
  }

  const getCacheKey = (): string => {
    return (previewAnon?.checked ? 'anon;' : '') + textarea!.value;
  };

  const previewedTextAttribute = 'data-previewed-text';
  const updatePreview = () => {
    const cachedValue = getCacheKey();
    if (previewContent.getAttribute(previewedTextAttribute) === cachedValue) return;
    previewContent.setAttribute(previewedTextAttribute, cachedValue);

    getPreview(textarea!.value, Boolean(previewAnon?.checked), previewLoading, previewIdle, previewContent);
  };

  previewButton.addEventListener('click', updatePreview);
  textarea.addEventListener('change', resizeTextarea);
  textarea.addEventListener('keyup', resizeTextarea);

  // Fire handler for automatic resizing if textarea contains text on page load (e.g. editing)
  if (textarea.value) textarea.dispatchEvent(new Event('change'));

  if (previewAnon) {
    previewAnon.addEventListener('click', () => {
      if (previewContent.classList.contains('hidden')) return;

      updatePreview();
    });
  }

  delegate(document, 'click', {
    '.post-reply': (event: Event, link: HTMLElement) => {
      commentReply(link.dataset.author || '', link.getAttribute('href') || '', textarea!, link.dataset.post);
      event.preventDefault();
    },
  });
}

export { setupPreviews };
