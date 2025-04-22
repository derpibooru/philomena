import { makeEl } from './dom.ts';
import { MatchPart, TagSuggestion } from './suggestions-model.ts';

export class TagSuggestionComponent {
  data: TagSuggestion;

  constructor(data: TagSuggestion) {
    this.data = data;
  }

  value(): string {
    if (typeof this.data.canonical === 'string') {
      return this.data.canonical;
    }

    return this.data.canonical.map(part => (typeof part === 'string' ? part : part.matched)).join('');
  }

  render(): HTMLElement[] {
    const { data } = this;

    return [
      makeEl('div', { className: 'autocomplete__item__content' }, [
        makeEl('i', { className: 'fa-solid fa-tag' }),
        ' ',
        ...this.renderLabel(),
      ]),
      makeEl('span', {
        className: 'autocomplete__item__tag__count',
        textContent: `  ${TagSuggestionComponent.renderImageCount(data.images)}`,
      }),
    ];
  }

  renderLabel(): (HTMLElement | string)[] {
    const { data } = this;

    if (!data.alias) {
      return TagSuggestionComponent.renderMatchParts(data.canonical);
    }

    return [...TagSuggestionComponent.renderMatchParts(data.alias), ` → ${data.canonical}`];
  }

  static renderMatchParts(parts: MatchPart[]): (HTMLElement | string)[] {
    return parts.map(part => {
      if (typeof part === 'string') {
        return part;
      }

      return makeEl('b', {
        className: 'autocomplete__item__tag__match',
        textContent: part.matched,
      });
    });
  }

  static renderImageCount(count: number): string {
    // We use the 'fr' (French) number formatting style with space-separated
    // groups of 3 digits.
    const formatter = new Intl.NumberFormat('fr', { useGrouping: true });

    // Normalize the whitespace with a `.replace()`. We'll use CSS to guarantee
    // a smaller spacing between the groups of digits.
    return formatter.format(count).replace(/\s/g, ' ');
  }
}

export class HistorySuggestionComponent {
  /**
   * Full query string that was previously searched and retrieved from the history.
   */
  content: string;

  /**
   * Length of the prefix in the suggestion that matches the prefix of the current input.
   */
  matchLength: number;

  constructor(content: string, matchIndex: number) {
    this.content = content;
    this.matchLength = matchIndex;
  }

  value(): string {
    return this.content;
  }

  render(): HTMLElement[] {
    return [
      makeEl('div', { className: 'autocomplete__item__content' }, [
        makeEl('i', {
          className: 'autocomplete__item__history__icon fa-solid fa-history',
        }),
        makeEl('b', {
          textContent: ` ${this.content.slice(0, this.matchLength)}`,
          className: 'autocomplete__item__history__match',
        }),
        makeEl('span', {
          textContent: this.content.slice(this.matchLength),
        }),
      ]),
      // Here will be a `delete` button to remove the item from the history.
    ];
  }
}

export type Suggestion = TagSuggestionComponent | HistorySuggestionComponent;

export interface Suggestions {
  history: HistorySuggestionComponent[];
  tags: TagSuggestionComponent[];
}

export interface ItemSelectedEvent {
  suggestion: Suggestion;
  shiftKey: boolean;
  ctrlKey: boolean;
}

interface SuggestionItem {
  element: HTMLElement;
  suggestion: Suggestion;
}

/**
 * Responsible for rendering the suggestions dropdown.
 */
export class SuggestionsPopupComponent {
  /**
   * Index of the currently selected suggestion. -1 means an imaginary item
   * before the first item that represents the state where no item is selected.
   */
  private cursor: number = -1;
  private items: SuggestionItem[];
  private readonly container: HTMLElement;

  constructor() {
    this.container = makeEl('div', {
      className: 'autocomplete hidden',
      tabIndex: -1,
    });

    document.body.appendChild(this.container);
    this.items = [];
  }

  get selectedSuggestion(): Suggestion | null {
    return this.selectedItem?.suggestion ?? null;
  }

  private get selectedItem(): SuggestionItem | null {
    if (this.cursor < 0) {
      return null;
    }

    return this.items[this.cursor];
  }

  get isHidden(): boolean {
    return this.container.classList.contains('hidden');
  }

  hide() {
    this.clearSelection();
    this.container.classList.add('hidden');
  }

  private clearSelection() {
    this.setSelection(-1);
  }

  private setSelection(index: number) {
    if (this.cursor === index) {
      return;
    }

    // This can't be triggered via the public API of this class
    /* v8 ignore start */
    if (index < -1 || index >= this.items.length) {
      throw new Error(`BUG: setSelection(): invalid selection index: ${index}`);
    }
    /* v8 ignore end */

    const selectedClass = 'autocomplete__item--selected';

    this.selectedItem?.element.classList.remove(selectedClass);
    this.cursor = index;

    if (index >= 0) {
      this.selectedItem?.element.classList.add(selectedClass);
    }
  }

  setSuggestions(params: Suggestions): SuggestionsPopupComponent {
    this.cursor = -1;
    this.items = [];
    this.container.innerHTML = '';

    for (const suggestion of params.history) {
      this.appendSuggestion(suggestion);
    }

    if (params.tags.length > 0 && params.history.length > 0) {
      this.container.appendChild(makeEl('hr', { className: 'autocomplete__separator' }));
    }

    for (const suggestion of params.tags) {
      this.appendSuggestion(suggestion);
    }

    return this;
  }

  appendSuggestion(suggestion: Suggestion) {
    const type = suggestion instanceof TagSuggestionComponent ? 'tag' : 'history';

    const element = makeEl(
      'div',
      {
        className: `autocomplete__item autocomplete__item__${type}`,
      },
      suggestion.render(),
    );

    const item: SuggestionItem = { element, suggestion };

    this.watchItem(item);

    this.items.push(item);
    this.container.appendChild(element);
  }

  private watchItem(item: SuggestionItem) {
    item.element.addEventListener('click', event => {
      const detail: ItemSelectedEvent = {
        suggestion: item.suggestion,
        shiftKey: event.shiftKey,
        ctrlKey: event.ctrlKey,
      };

      this.container.dispatchEvent(new CustomEvent('item_selected', { detail }));
    });
  }

  private changeSelection(direction: number) {
    if (this.items.length === 0) {
      return;
    }

    const index = this.cursor + direction;

    if (index === -1 || index >= this.items.length) {
      this.clearSelection();
    } else if (index < -1) {
      this.setSelection(this.items.length - 1);
    } else {
      this.setSelection(index);
    }
  }

  selectDown() {
    this.changeSelection(1);
  }

  selectUp() {
    this.changeSelection(-1);
  }

  /**
   * The user wants to jump to the next lower block of types of suggestions.
   */
  selectCtrlDown() {
    if (this.items.length === 0) {
      return;
    }

    if (this.cursor >= this.items.length - 1) {
      this.setSelection(0);
      return;
    }

    let index = this.cursor + 1;
    const type = this.itemType(index);

    while (index < this.items.length - 1 && this.itemType(index) === type) {
      index += 1;
    }

    this.setSelection(index);
  }

  /**
   * The user wants to jump to the next upper block of types of suggestions.
   */
  selectCtrlUp() {
    if (this.items.length === 0) {
      return;
    }

    if (this.cursor <= 0) {
      this.setSelection(this.items.length - 1);
      return;
    }

    let index = this.cursor - 1;
    const type = this.itemType(index);

    while (index > 0 && this.itemType(index) === type) {
      index -= 1;
    }

    this.setSelection(index);
  }

  /**
   * Returns the item's prototype that can be viewed as the item's type identifier.
   */
  private itemType(index: number) {
    return this.items[index].suggestion instanceof TagSuggestionComponent ? 'tag' : 'history';
  }

  showForElement(targetElement: HTMLElement) {
    if (this.items.length === 0) {
      // Hide the popup because there are no suggestions to show. We have to do it
      // explicitly, because a border is still rendered even for an empty popup.
      this.hide();
      return;
    }

    this.container.style.position = 'absolute';
    this.container.style.left = `${targetElement.offsetLeft}px`;

    let topPosition = targetElement.offsetTop + targetElement.offsetHeight;

    if (targetElement.parentElement) {
      topPosition -= targetElement.parentElement.scrollTop;
    }

    this.container.style.top = `${topPosition}px`;
    this.container.classList.remove('hidden');
  }

  onItemSelected(callback: (event: ItemSelectedEvent) => void) {
    this.container.addEventListener('item_selected', event => {
      callback((event as CustomEvent<ItemSelectedEvent>).detail);
    });
  }
}
