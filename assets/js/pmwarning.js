/**
 * PmWarning
 *
 * Warn users that their PM will be reviewed.
 */

import { $ } from './utils/dom';

function warnAboutPMs() {
  const textarea = $('.js-toolbar-input');
  const warning = $('.js-hidden-warning');
  const imageEmbedRegex = /!+\[/g;

  if (!warning || !textarea) return;

  textarea.addEventListener('input', () => {
    const value = textarea.value;

    if (value.match(imageEmbedRegex)) {
      warning.classList.remove('hidden');
    }
    else if (!warning.classList.contains('hidden')) {
      warning.classList.add('hidden');
    }
  });
}

export { warnAboutPMs };
