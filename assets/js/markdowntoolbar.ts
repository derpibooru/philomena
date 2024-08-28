/**
 * Markdown toolbar
 */

import { $, $$ } from './utils/dom';

// List of options provided to the syntax handler function.
interface SyntaxHandlerOptions {
  prefix: string;
  shortcutKeyCode: number;
  suffix: string;
  prefixMultiline: string;
  suffixMultiline: string;
  singleWrap: boolean;
  escapeChar: string;
  image: boolean;
  text: string;
}

interface SyntaxHandler {
  action: (textarea: HTMLTextAreaElement, options: Partial<SyntaxHandlerOptions>) => void;
  options: Partial<SyntaxHandlerOptions>;
}

const markdownSyntax: Record<string, SyntaxHandler> = {
  bold: {
    action: wrapSelection,
    options: { prefix: '**', shortcutKeyCode: 66 },
  },
  italics: {
    action: wrapSelection,
    options: { prefix: '*', shortcutKeyCode: 73 },
  },
  under: {
    action: wrapSelection,
    options: { prefix: '__', shortcutKeyCode: 85 },
  },
  spoiler: {
    action: wrapSelection,
    options: { prefix: '||', shortcutKeyCode: 83 },
  },
  code: {
    action: wrapSelectionOrLines,
    options: {
      prefix: '`',
      suffix: '`',
      prefixMultiline: '```\n',
      suffixMultiline: '\n```',
      singleWrap: true,
      shortcutKeyCode: 69,
    },
  },
  strike: {
    action: wrapSelection,
    options: { prefix: '~~' },
  },
  superscript: {
    action: wrapSelection,
    options: { prefix: '^' },
  },
  subscript: {
    action: wrapSelection,
    options: { prefix: '%' },
  },
  quote: {
    action: wrapLines,
    options: { prefix: '> ' },
  },
  link: {
    action: insertLink,
    options: { shortcutKeyCode: 76 },
  },
  image: {
    action: insertLink,
    options: { image: true, shortcutKeyCode: 75 },
  },
  escape: {
    action: escapeSelection,
    options: { escapeChar: '\\' },
  },
};

interface SelectionResult {
  processLinesOnly: boolean;
  selectedText: string;
  beforeSelection: string;
  afterSelection: string;
}

function getSelections(textarea: HTMLTextAreaElement, linesOnly: RegExp | boolean = false): SelectionResult {
  let { selectionStart, selectionEnd } = textarea,
    selection = textarea.value.substring(selectionStart, selectionEnd),
    leadingSpace = '',
    trailingSpace = '',
    caret: number;

  const processLinesOnly = linesOnly instanceof RegExp ? linesOnly.test(selection) : linesOnly;

  if (processLinesOnly) {
    const explorer = /\n/g;
    let startNewlineIndex = 0,
      endNewlineIndex = textarea.value.length;
    while (explorer.exec(textarea.value)) {
      const { lastIndex } = explorer;
      if (lastIndex <= selectionStart) {
        startNewlineIndex = lastIndex;
      } else if (lastIndex > selectionEnd) {
        endNewlineIndex = lastIndex - 1;
        break;
      }
    }

    selectionStart = startNewlineIndex;
    const startRemovedValue = textarea.value.substring(selectionStart);
    const startsWithBlankString = startRemovedValue.match(/^[\s\n]+/);
    if (startsWithBlankString) {
      // Offset the selection start to the first non-blank line's first non-blank character, since
      // Some browsers treat selection up to the start of the line as including the end of the
      // previous line
      selectionStart += startsWithBlankString[0].length;
    }
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
    processLinesOnly,
    selectedText: selection,
    beforeSelection: textarea.value.substring(0, selectionStart) + leadingSpace,
    afterSelection: trailingSpace + textarea.value.substring(selectionEnd),
  };
}

interface TransformResult {
  newText: string;
  caretOffset: number;
}

type TransformCallback = (selectedText: string, processLinesOnly: boolean) => TransformResult;

function transformSelection(
  textarea: HTMLTextAreaElement,
  transformer: TransformCallback,
  eachLine: RegExp | boolean = false,
) {
  const { selectedText, beforeSelection, afterSelection, processLinesOnly } = getSelections(textarea, eachLine),
    // For long comments, record scrollbar position to restore it later
    { scrollTop } = textarea;

  const { newText, caretOffset } = transformer(selectedText, processLinesOnly);

  textarea.value = beforeSelection + newText + afterSelection;

  const newSelectionStart =
    caretOffset >= 1
      ? beforeSelection.length + caretOffset
      : textarea.value.length - afterSelection.length - caretOffset;

  textarea.selectionStart = newSelectionStart;
  textarea.selectionEnd = newSelectionStart;
  textarea.scrollTop = scrollTop;
  // Needed for automatic textarea resizing
  textarea.dispatchEvent(new Event('change'));
}

function insertLink(textarea: HTMLTextAreaElement, options: Partial<SyntaxHandlerOptions>) {
  let hyperlink = window.prompt(options.image ? 'Image link:' : 'Link:');
  if (!hyperlink || hyperlink === '') return;

  // Change on-site link to use relative url
  if (!options.image && hyperlink.startsWith(window.location.origin)) {
    hyperlink = hyperlink.substring(window.location.origin.length);
  }

  const prefix = options.image ? '![' : '[',
    suffix = `](${hyperlink})`;

  wrapSelection(textarea, { prefix, suffix });
}

function wrapSelection(textarea: HTMLTextAreaElement, options: Partial<SyntaxHandlerOptions>) {
  transformSelection(textarea, (selectedText: string): TransformResult => {
    const { text = selectedText, prefix = '', suffix = options.prefix } = options,
      emptyText = text === '';

    let newText = text;

    if (!emptyText) {
      newText = text.replace(/(\n{2,})/g, match => {
        return suffix + match + prefix;
      });
    }

    newText = prefix + newText + suffix;

    return {
      newText,
      caretOffset: emptyText ? prefix.length : newText.length,
    };
  });
}

function wrapLines(
  textarea: HTMLTextAreaElement,
  options: Partial<SyntaxHandlerOptions>,
  eachLine: RegExp | boolean = true,
) {
  transformSelection(
    textarea,
    (selectedText: string, processLinesOnly: boolean): TransformResult => {
      const { text = selectedText, singleWrap = false } = options,
        prefix = (processLinesOnly && options.prefixMultiline) || options.prefix || '',
        suffix = (processLinesOnly && options.suffixMultiline) || options.suffix || '',
        emptyText = text === '';
      let newText = singleWrap
        ? prefix + text.trim() + suffix
        : text
            .split(/\n/g)
            .map(line => prefix + line.trim() + suffix)
            .join('\n');

      // Force a space at the end of lines with only blockquote markers
      newText = newText.replace(/^((?:>\s+)*)>$/gm, '$1> ');

      return { newText, caretOffset: emptyText ? prefix.length : newText.length };
    },
    eachLine,
  );
}

function wrapSelectionOrLines(textarea: HTMLTextAreaElement, options: Partial<SyntaxHandlerOptions>) {
  wrapLines(textarea, options, /\n/);
}

function escapeSelection(textarea: HTMLTextAreaElement, options: Partial<SyntaxHandlerOptions>) {
  transformSelection(textarea, (selectedText: string): TransformResult => {
    const { text = selectedText } = options,
      emptyText = text === '';

    // Even if there is nothing to escape, we still need to return the result, otherwise the error would be thrown.
    if (emptyText) {
      return {
        newText: text,
        caretOffset: text.length,
      };
    }

    const newText = text.replace(/([*_[\]()^`%\\~<>#|])/g, '\\$1');

    return {
      newText,
      caretOffset: newText.length,
    };
  });
}

function clickHandler(event: MouseEvent) {
  if (!(event.target instanceof HTMLElement)) return;

  const button = event.target?.closest<HTMLElement>('.communication__toolbar__button');
  const toolbar = button?.closest<HTMLElement>('.communication__toolbar');

  if (!button || !toolbar?.parentElement) return;

  // There may be multiple toolbars present on the page,
  // in the case of image pages with description edit active
  // we target the textarea that shares the same parent as the toolbar
  const textarea = $<HTMLTextAreaElement>('.js-toolbar-input', toolbar.parentElement),
    id = button.dataset.syntaxId;

  if (!textarea || !id) return;

  markdownSyntax[id].action(textarea, markdownSyntax[id].options);
  textarea.focus();
}

function canAcceptShortcut(event: KeyboardEvent): boolean {
  let ctrl: boolean, otherModifier: boolean;

  switch (window.navigator.platform) {
    case 'MacIntel':
      ctrl = event.metaKey;
      otherModifier = event.ctrlKey || event.shiftKey || event.altKey;
      break;
    default:
      ctrl = event.ctrlKey;
      otherModifier = event.metaKey || event.shiftKey || event.altKey;
      break;
  }

  return ctrl && !otherModifier;
}

function shortcutHandler(event: KeyboardEvent) {
  if (!canAcceptShortcut(event)) {
    return;
  }

  const textarea = event.target,
    keyCode = event.keyCode;

  if (!(textarea instanceof HTMLTextAreaElement)) return;

  for (const id in markdownSyntax) {
    if (keyCode === markdownSyntax[id].options.shortcutKeyCode) {
      markdownSyntax[id].action(textarea, markdownSyntax[id].options);
      event.preventDefault();
    }
  }
}

function setupToolbar() {
  $$<HTMLElement>('.communication__toolbar').forEach(toolbar => {
    toolbar.addEventListener('click', clickHandler);
  });
  $$<HTMLTextAreaElement>('.js-toolbar-input').forEach(textarea => {
    textarea.addEventListener('keydown', shortcutHandler);
  });
}

export { setupToolbar };
