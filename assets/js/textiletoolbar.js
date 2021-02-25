/**
 * Textile toolbar
 *
 */

import { $, $$ } from './utils/dom';

const textileSyntax = {
  bold: {
    action: wrapSelection,
    options: { prefix: '*', suffix: '*', shortcutKey: 'b', type: 'inline' }
  },
  italics: {
    action: wrapSelection,
    options: { prefix: '_', suffix: '_', shortcutKey: 'i', type: 'inline' }
  },
  under: {
    action: wrapSelection,
    options: { prefix: '+', suffix: '+', shortcutKey: 'u', type: 'inline' }
  },
  spoiler: {
    action: wrapSelection,
    options: { prefix: '[spoiler]', suffix: '[/spoiler]', shortcutKey: 's' }
  },
  code: {
    action: wrapSelection,
    options: { prefix: '@', suffix: '@', shortcutKey: 'e', type: 'inline' }
  },
  strike: {
    action: wrapSelection,
    options: { prefix: '-', suffix: '-', type: 'inline' }
  },
  superscript: {
    action: wrapSelection,
    options: { prefix: '^', suffix: '^', type: 'inline' }
  },
  subscript: {
    action: wrapSelection,
    options: { prefix: '~', suffix: '~', type: 'inline' }
  },
  quote: {
    action: wrapSelection,
    options: { prefix: '[bq]', suffix: '[/bq]' }
  },
  link: {
    action: insertLink,
    options: { prefix: '"', suffix: '":', shortcutKey: 'l' }
  },
  image: {
    action: insertImage,
    options: { prefix: '!', suffix: '!', shortcutKey: 'k' }
  },
  noParse: {
    action: wrapSelection,
    options: { prefix: '[==', suffix: '==]' }
  },
};

function getSelections(textarea) {
  let selection = textarea.value.substring(textarea.selectionStart, textarea.selectionEnd),
      leadingSpace = '',
      trailingSpace = '',
      caret;

  // Deselect trailing space and line break
  for (caret = selection.length - 1; caret > 0; caret--) {
    if (selection[caret] !== ' ' && selection[caret] !== '\n') break;
    trailingSpace = selection[caret] + trailingSpace;
  }
  selection = selection.substring(0, caret + 1);

  // Deselect leading space and line break
  for (caret = 0; caret < selection.length; caret++) {
    if (selection[caret] !== ' ' && selection[caret] !== '\n') break;
    leadingSpace += selection[caret];
  }
  selection = selection.substring(caret);

  return {
    selectedText: selection,
    beforeSelection: textarea.value.substring(0, textarea.selectionStart) + leadingSpace,
    afterSelection: trailingSpace + textarea.value.substring(textarea.selectionEnd),
  };
}

function wrapSelection(textarea, options) {
  const { selectedText, beforeSelection, afterSelection } = getSelections(textarea),
        { text = selectedText, prefix = '', suffix = '', type } = options,
        // For long comments, record scrollbar position to restore it later
        scrollTop = textarea.scrollTop,
        emptyText = text === '';

  const newText = text;

  if (type === 'inline' && newText.includes('\n')) {
    textarea.value = `${beforeSelection}[${prefix}${newText}${suffix}]${afterSelection}`;
  }
  else {
    textarea.value = `${beforeSelection}${prefix}${newText}${suffix}${afterSelection}`;
  }

  // If no text were highlighted, place the caret inside
  // the formatted section, otherwise place it at the end
  if (emptyText) {
    textarea.selectionEnd = textarea.value.length - afterSelection.length - suffix.length;
  }
  else {
    textarea.selectionEnd = textarea.value.length - afterSelection.length;
  }
  textarea.selectionStart = textarea.selectionEnd;
  textarea.scrollTop = scrollTop;
}

function insertLink(textarea, options) {
  let hyperlink = window.prompt('Link:');
  if (!hyperlink || hyperlink === '') return;

  // Change on-site link to use relative url
  if (hyperlink.startsWith(window.location.origin)) hyperlink = hyperlink.substring(window.location.origin.length);

  const prefix = options.prefix,
        suffix = options.suffix + hyperlink;

  wrapSelection(textarea, { prefix, suffix });
}

function insertImage(textarea, options) {
  const hyperlink          = window.prompt('Image link:');
  const { prefix, suffix } = options;

  if (!hyperlink || hyperlink === '') return;

  wrapSelection(textarea, { text: hyperlink, prefix, suffix });
}

function clickHandler(event) {
  const button = event.target.closest('.communication__toolbar__button');
  if (!button) return;
  const toolbar  = button.closest('.communication__toolbar'),
        // There may be multiple toolbars present on the page,
        // in the case of image pages with description edit active
        // we target the textarea that shares the same parent as the toolabr
        textarea = $('.js-toolbar-input', toolbar.parentNode),
        id       = button.dataset.syntaxId;

  textileSyntax[id].action(textarea, textileSyntax[id].options);
  textarea.focus();
}

function shortcutHandler(event) {
  if (!event.ctrlKey || (window.navigator.platform === 'MacIntel' && !event.metaKey) || event.shiftKey || event.altKey) return;
  const textarea = event.target,
        key      = event.key.toLowerCase();

  for (const id in textileSyntax) {
    if (key === textileSyntax[id].options.shortcutKey) {
      textileSyntax[id].action(textarea, textileSyntax[id].options);
      event.preventDefault();
    }
  }
}

function setupToolbar() {
  $$('.communication__toolbar').forEach(toolbar => {
    toolbar.addEventListener('click', clickHandler);
  });
  $$('.js-toolbar-input').forEach(textarea => {
    textarea.addEventListener('keydown', shortcutHandler);
  });
}

export { setupToolbar };
