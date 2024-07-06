/**
 * PmWarning
 *
 * Warn users that their PM will be reviewed.
 */

import { $, hideEl, showEl } from './utils/dom';

export function warnAboutPMs() {
  const textarea = $<HTMLTextAreaElement>('.js-toolbar-input');
  const warning = $<HTMLDivElement>('.js-hidden-warning');
  const imageEmbedRegex = /!+\[/g;

  if (!warning || !textarea) return;

  textarea.addEventListener('input', () => {
    const value = textarea.value;

    if (value.match(imageEmbedRegex)) {
      showEl(warning);
    } else {
      hideEl(warning);
    }
  });
}
