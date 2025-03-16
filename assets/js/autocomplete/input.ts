import store from '../utils/store';
import { getTermContexts } from '../match_query';
import { Range } from '../query/lex';

export type TextInputElement = HTMLInputElement | HTMLTextAreaElement;

/**
 * Describes the term, that the cursor is currently on, which is known as "active".
 * If any tag completion is accepted, this term will be overwritten in the input.
 * The rest of the input will be left untouched.
 */
interface ActiveTerm {
  range: Range;

  /**
   * The term itself. Stripped from the `prefix` if it's present, and also lowercased.
   */
  term: string;

  /**
   * Optional `-` prefix is only relevant for the `single-tag` autocompletion type.
   * This prefix is extracted automatically from the `term` value and is used to
   * signal that the tag should be removed from the list.
   */
  prefix: '-' | '';
}

/**
 * Captures the value of the input at the time when the `AutocompletableInput` was created.
 */
interface AutocompleteInputSnapshot {
  /**
   * Original value of the input element at the time when it was created unmodified.
   */
  origValue: string;

  /**
   * The value of the input element at the time when it was created, but
   * trimmed from whitespace.
   */
  trimmedValue: string;

  /**
   * Can be `null` if the input value is empty.
   */
  activeTerm: ActiveTerm | null;

  /**
   * Cursor selection at the time when the snapshot was taken.
   */
  selection: {
    start: number | null;
    end: number | null;
    direction: TextInputElement['selectionDirection'];
  };
}

/**
 * The `multi-tags` autocompletion type is used to power inputs with complex
 * search queries like `(tag1 OR tag2), tag3` and tag lists like `tag1, tag2, tag3`
 * in the plain tag search/edit inputs.
 *
 * The `single-tag` autocompletion type is used to power the fancy tag editor
 * that manages separate input elements for every tag. In this mode the user
 * can input `-tag` prefix to remove the tag from the list. See more details
 * about how it works here: https://github.com/philomena-dev/philomena/pull/383
 */
type AutocompleteInputType = 'multi-tags' | 'single-tag';

/**
 * Parsed version of `TextInputElement`. Its behavior is controlled with various
 * `data-autocomplete*` attributes.
 */
export class AutocompletableInput {
  /**
   * HTML element that autocomplete is attached to.
   */
  readonly element: TextInputElement;

  readonly type: AutocompleteInputType;

  /**
   * Captures the value of the input at the time when the `AutocompletableInput` was created.
   */
  readonly snapshot: AutocompleteInputSnapshot;

  /**
   * Defines the name of the parameter in `localStorage` that should be read
   * to conditionally enable the autocomplete feature.
   */
  readonly condition?: string;

  /**
   * An integer that overrides the default limit of maximum suggestions to show.
   */
  readonly maxSuggestions: number;

  /**
   * If present enables the history feature for the input element. The value
   * of this property defines the key in the `localStorage` where the history
   * records are stored.
   */
  readonly historyId?: string;

  /**
   * Returns `null` only if the element is not autocomplete-capable.
   */
  static fromElement(element: unknown): AutocompletableInput | null {
    if (!(element instanceof HTMLInputElement || element instanceof HTMLTextAreaElement)) {
      return null;
    }

    // This attribute marks the element as autocomplete-capable. It doesn't necessarily
    // mean that the autocomplete **will** show up for the element. It may be disabled
    // based on the setting value from the key specified under the attribute
    // `data-autocomplete-condition`.
    if (!element.dataset.autocomplete) {
      return null;
    }

    return new AutocompletableInput(element);
  }

  private constructor(element: TextInputElement) {
    this.element = element;
    this.condition = element.dataset.autocompleteCondition;
    this.historyId = element.dataset.autocompleteHistoryId;

    const type = element.dataset.autocomplete;

    if (type !== 'multi-tags' && type !== 'single-tag') {
      throw new Error(`BUG: invalid autocomplete type: ${type}`);
    }

    this.type = type;
    this.snapshot = {
      origValue: element.value,
      trimmedValue: element.value.trim(),
      activeTerm: findActiveTerm(type, element),
      selection: {
        start: element.selectionStart,
        end: element.selectionEnd,
        direction: element.selectionDirection,
      },
    };

    const maxSuggestions = element.dataset.autocompleteMaxSuggestions;

    this.maxSuggestions = maxSuggestions ? parseInt(maxSuggestions, 10) : 10;
  }

  hasHistory(): this is this & { historyId: string } {
    return Boolean(this.historyId);
  }

  isEnabled(): boolean {
    return !this.condition || store.get<boolean>(this.condition) || false;
  }
}

function findActiveTerm(
  autocompleteType: AutocompleteInputType,
  { value, selectionStart, selectionEnd }: TextInputElement,
): ActiveTerm | null {
  if (selectionStart === null || selectionEnd === null) return null;

  // Technically the user may select several characters and several terms at once,
  // but we just take the first one from the selection as the "cursor" index.
  const cursorIndex = Math.min(selectionStart, selectionEnd);

  // Multi-line textarea elements should treat each line as different search queries.
  // Here we're looking for the actively edited line and use it instead of the whole value.
  const lineStart = value.lastIndexOf('\n', cursorIndex) + 1;
  const lineEnd = Math.max(value.indexOf('\n', cursorIndex), value.length);
  const line = value.slice(lineStart, lineEnd);

  const terms = getTermContexts(line);
  const searchIndex = cursorIndex - lineStart;

  const term = terms.find(({ range }) => range.start <= searchIndex && range.end >= searchIndex) ?? null;

  if (!term) {
    return null;
  }

  const { range } = term;
  const content = term.content.toLowerCase();
  const stripDash = content.startsWith('-') && autocompleteType === 'single-tag';

  return {
    term: stripDash ? content.slice(1) : content,
    prefix: stripDash ? '-' : '',
    range: {
      // Convert line-specific indexes back to absolute ones.
      start: range.start + lineStart,
      end: range.end + lineStart,
    },
  };
}
