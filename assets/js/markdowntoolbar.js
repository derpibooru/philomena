/**
 * Markdown toolbar
 */

import { $, $$, showEl } from './utils/dom';

const markdownSyntax = {
  bold: {
    action: wrapSelection,
    options: { prefix: '**', shortcutKey: 'b' }
  },
  italics: {
    action: wrapSelection,
    options: { prefix: '*', shortcutKey: 'i' }
  },
  under: {
    action: wrapSelection,
    options: { prefix: '__', shortcutKey: 'u' }
  },
  spoiler: {
    action: wrapSelection,
    options: { prefix: '||', shortcutKey: 's' }
  },
  code: {
    action: wrapSelection,
    options: { prefix: '`', shortcutKey: 'e' }
  },
  strike: {
    action: wrapSelection,
    options: { prefix: '~~' }
  },
  superscript: {
    action: wrapSelection,
    options: { prefix: '^' }
  },
  subscript: {
    action: wrapSelection,
    options: { prefix: '%' }
  },
  quote: {
    action: wrapLines,
    options: { prefix: '> ' }
  },
  link: {
    action: insertLink,
    options: { shortcutKey: 'l' }
  },
  image: {
    action: insertLink,
    options: { image: true, shortcutKey: 'k' }
  },
  noParse: {
    action: escapeSelection,
    options: { escapeChar: '\\' }
  },
};

function getSelections(textarea, linesOnly = false) {
  let { selectionStart, selectionEnd } = textarea,
      selection = textarea.value.substring(selectionStart, selectionEnd),
      leadingSpace = '',
      trailingSpace = '',
      caret;

  if (linesOnly) {
    let startNewlineIndex = 0,
        endNewlineIndex = textarea.value.length,
        explorer = /\n/g;
    while (explorer.exec(textarea.value)) {
      const { lastIndex } = explorer;
      if (lastIndex < selectionStart) {
        startNewlineIndex = lastIndex + 1;
      } else if (lastIndex > selectionEnd) {
        endNewlineIndex = lastIndex;
        break;
      }
    }

    selectionStart = startNewlineIndex;
    selectionEnd = endNewlineIndex;
    selection = textarea.value.substring(selectionStart, selectionEnd);
  } else {
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
  }

  return {
    selectedText: selection,
    beforeSelection: textarea.value.substring(0, selectionStart) + leadingSpace,
    afterSelection: trailingSpace + textarea.value.substring(selectionEnd),
  };
}

function getSurroundingTwoLines(beforeText, afterText) {
  // Selection typically includes the new line right before it
  // therefore you need to include two lines before and after
  return {
    twoLinesBefore: beforeText.split('\n').slice(-2).join('\n'),
    twoLinesAfter: afterText.split('\n').slice(0, 2).join('\n'),
  }
}

function transformSelection(textarea, transformer, eachLine) {
  const { selectedText, beforeSelection, afterSelection } = getSelections(textarea, eachLine),
        // For long comments, record scrollbar position to restore it later
        { scrollTop } = textarea;

  const { newText, caretOffset } = transformer(selectedText, beforeSelection, afterSelection);

  textarea.value = beforeSelection + newText + afterSelection;

  const newSelectionStart = caretOffset >= 1
    ? beforeSelection.length + caretOffset
    : textarea.value.length - afterSelection.length - caretOffset;

  textarea.selectionStart = newSelectionStart;
  textarea.selectionEnd = newSelectionStart;
  textarea.scrollTop = scrollTop;
  textarea.dispatchEvent(new Event('keydown'));
}

function insertLink(textarea, options) {
  let hyperlink = window.prompt(options.image ? 'Image link:' : 'Link:');
  if (!hyperlink || hyperlink === '') return;

  // Change on-site link to use relative url
  if (!options.image && hyperlink.startsWith(window.location.origin)) {
    hyperlink = hyperlink.substring(window.location.origin.length);
  }

  const prefix = options.image ? '![' : '[',
        suffix = '](' + escapeHyperlink(hyperlink) + ')';

  wrapSelection(textarea, { prefix, suffix });
}

function wrapSelection(textarea, options) {
  transformSelection(textarea, selectedText => {
    const { text = selectedText, prefix = '', suffix = options.prefix } = options,
          emptyText = text === '';
    let newText = text;

    if (!emptyText) {
      newText = text.replace(/(\n{2,})/g, match => {
        return suffix + match + prefix;
      });
    }

    return {
      newText: prefix + newText + suffix,
      caretOffset: emptyText ? prefix.length : -suffix.length,
    };
  })
}

function wrapLines(textarea, options) {
  transformSelection(textarea, (selectedText, before, after) => {
    const { text = selectedText, prefix = '', suffix = '' } = options,
          { twoLinesBefore, twoLinesAfter } = getSurroundingTwoLines(before, after),
          emptyText = text === '';
    let newText = prefix;

    if (!emptyText) {
      newText = text.split(/\n/g).map(line => prefix + (line.trim()) + suffix).join('\n');
    } else {
      newText += suffix;
    }

    // Add blank lines before/after if surrounding line are not empty
    if (isNotBlank(twoLinesBefore)) newText = '\n' + newText;
    if (isNotBlank(twoLinesAfter)) newText += '\n';

    return { newText, caretOffset: newText.length - suffix.length };
  })
}

function escapeSelection(textarea, options) {
  transformSelection(textarea, selectedText => {
    const { text = selectedText } = options,
          emptyText = text === '';

    if (emptyText) return;

    let newText = text.replace(/([\[\]()*_`\\~<>^])/g, '\\$1').replace(/\|\|/g, '\\|\\|');

    return {
      newText: newText,
      caretOffset: newText.length,
    };
  })
}

function escapeHyperlink(url) {
  return typeof url === 'string' ? url.replace(/([()])/g, '\\$1') : url;
}

function isNotBlank(string) {
  return /\S/.test(string);
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

  markdownSyntax[id].action(textarea, markdownSyntax[id].options);
  textarea.focus();
}

function shortcutHandler(event) {
  if (!event.ctrlKey || (window.navigator.platform === 'MacIntel' && !event.metaKey) || event.shiftKey || event.altKey) return;
  const textarea = event.target,
        key      = event.key.toLowerCase();

  for (const id in markdownSyntax) {
    if (key === markdownSyntax[id].options.shortcutKey) {
      markdownSyntax[id].action(textarea, markdownSyntax[id].options);
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

  // Transform non-JS basic editor to two-column layout with preview
  $$('.js-preview-input-wrapper').forEach(wrapper => {
    wrapper.classList.remove('block__column--full');
    wrapper.classList.add('block__column--half');
  });
  $$('.js-preview-output-wrapper').forEach(wrapper => {
    showEl(wrapper)
  });
}

export { setupToolbar };
