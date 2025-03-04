import { makeEl } from './dom.ts';

export interface TagSuggestionParams {
  /**
   * If present, then this suggestion is for a tag alias.
   * If absent, then this suggestion is for the `canonical` tag name.
   */
  alias?: null | string;

  /**
   * The canonical name of the tag (non-alias).
   */
  canonical: string;

  /**
   * Number of images tagged with this tag.
   */
  images: number;

  /**
   * Length of the prefix in the suggestion that matches the prefix of the current input.
   */
  matchLength: number;
}

export class TagSuggestion {
  alias?: null | string;
  canonical: string;
  images: number;
  matchLength: number;

  constructor(params: TagSuggestionParams) {
    this.alias = params.alias;
    this.canonical = params.canonical;
    this.images = params.images;
    this.matchLength = params.matchLength;
  }

  value(): string {
    return this.canonical;
  }

  render(): HTMLElement[] {
    const { alias: aliasName, canonical: canonicalName, images: imageCount } = this;

    const label = aliasName ? `${aliasName} → ${canonicalName}` : canonicalName;

    return [
      makeEl('div', { className: 'autocomplete__item__content' }, [
        makeEl('i', { className: 'fa-solid fa-tag' }),
        makeEl('b', {
          className: 'autocomplete__item__tag__match',
          textContent: ` ${label.slice(0, this.matchLength)}`,
        }),
        makeEl('span', {
          textContent: label.slice(this.matchLength),
        }),
      ]),
      makeEl('span', {
        className: 'autocomplete__item__tag__count',
        textContent: `  ${TagSuggestion.formatImageCount(imageCount)}`,
      }),
    ];
  }

  static formatImageCount(count: number): string {
    const chars = [...count.toString()];

    for (let i = chars.length - 3; i > 0; i -= 3) {
      chars.splice(i, 0, ' ');
    }

    return chars.join('');
  }
}

export class HistorySuggestion {
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

export type Suggestion = TagSuggestion | HistorySuggestion;

export interface Suggestions {
  history: HistorySuggestion[];
  tags: TagSuggestion[];
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
export class SuggestionsPopup {
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

    // Make the container connected to DOM to make sure it's rendered when we unhide it
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

  setSuggestions(params: Suggestions): SuggestionsPopup {
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
    const type = suggestion instanceof TagSuggestion ? 'tag' : 'history';

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
    return this.items[index].suggestion instanceof TagSuggestion ? 'tag' : 'history';
  }

  showForElement(targetElement: HTMLElement) {
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
