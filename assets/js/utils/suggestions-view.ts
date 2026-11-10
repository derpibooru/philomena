import { makeEl } from './dom.ts';
import { MatchPart, TagSuggestion } from './suggestions-model.ts';
import { SuggestedProperty } from '../autocomplete/properties';

interface SuggestionComponent {
  readonly type: string;

  value(): string;

  render(): HTMLElement[];
}

export class TagSuggestionComponent implements SuggestionComponent {
  readonly type = 'tag';
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
    // The old implementation here was using new Intl.NumberFormat('fr'), but we
    // moved to a manual impl here to avoid platform-specific differences in
    // `Intl` implementation. It depends on the ICU package availability.
    const chars = [...count.toString()];

    for (let i = chars.length - 3; i > 0; i -= 3) {
      chars.splice(i, 0, ' ');
    }

    return chars.join('');
  }
}

export class HistorySuggestionComponent implements SuggestionComponent {
  readonly type = 'history';

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
      makeEl('div', { className: 'autocomplete__item__history__delete', title: 'Delete this history item' }, [
        makeEl('i', {
          className: 'fa-solid fa-xmark',
        }),
      ]),
    ];
  }
}

export class PropertySuggestionComponent implements SuggestionComponent {
  readonly type = 'property';
  suggestion: SuggestedProperty;

  constructor(content: SuggestedProperty) {
    this.suggestion = content;
  }

  value(): string {
    return this.suggestion.toString();
  }

  render(): HTMLElement[] {
    return [
      makeEl('div', { className: 'autocomplete__item__content' }, [
        makeEl('i', { className: 'fa-solid fa-circle-info' }),
        ' ',
        ...this.#renderSuggestionWithHighlighting(),
      ]),
    ];
  }

  #renderSuggestionWithHighlighting(): (HTMLElement | string)[] {
    const renderedSuggestion = this.value();
    const matchedLength = this.suggestion.calculateMatchedLength();

    const resultElements: (HTMLElement | string)[] = [
      makeEl('b', {
        className: 'autocomplete__item__property__match',
        textContent: renderedSuggestion.slice(0, matchedLength),
      }),
    ];

    if (matchedLength !== renderedSuggestion.length) {
      resultElements.push(renderedSuggestion.slice(matchedLength));
    }

    return resultElements;
  }
}

export type Suggestion = TagSuggestionComponent | HistorySuggestionComponent | PropertySuggestionComponent;

export interface Suggestions {
  history: HistorySuggestionComponent[];
  tags: TagSuggestionComponent[];
  properties: PropertySuggestionComponent[];
}

export interface ItemSelection {
  suggestion: Suggestion;
  shiftKey: boolean;
  ctrlKey: boolean;
}

interface SuggestionItem {
  element: HTMLElement;
  suggestion: Suggestion;
}

export interface HistoryItemDeleteDetail {
  suggestion: HistorySuggestionComponent;
  clickEvent: PointerEvent;
}

declare global {
  interface ItemSelectedEvent extends CustomEvent<ItemSelection> {
    target: HTMLElement;
  }

  interface HistoryItemDeleteEvent extends CustomEvent<HistoryItemDeleteDetail> {
    target: HTMLElement;
  }

  interface GlobalEventHandlersEventMap {
    itemselected: ItemSelectedEvent;
    historyitemdelete: HistoryItemDeleteEvent;
  }
}

/**
 * Responsible for rendering the suggestions dropdown.
 */
export class SuggestionsPopupComponent {
  /**
   * Index of the currently selected suggestion. -1 means an imaginary item
   * before the first item that represents the state where no item is selected.
   */
  private cursor = -1;
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

    if ((params.tags.length || params.history.length) && params.properties.length) {
      this.container.appendChild(makeEl('hr', { className: 'autocomplete__separator' }));
    }

    for (const suggestion of params.properties) {
      this.appendSuggestion(suggestion);
    }

    return this;
  }

  private appendSuggestion(suggestion: Suggestion) {
    const type = suggestion.type;

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
      if (
        item.suggestion.type === 'history' &&
        event.target instanceof HTMLElement &&
        event.target.closest('.autocomplete__item__history__delete')
      ) {
        const detail: HistoryItemDeleteDetail = {
          suggestion: item.suggestion,
          clickEvent: event,
        };
        this.container.dispatchEvent(new CustomEvent('historyitemdelete', { detail }));
        return;
      }

      const detail: ItemSelection = {
        suggestion: item.suggestion,
        shiftKey: event.shiftKey,
        ctrlKey: event.ctrlKey,
      };

      this.container.dispatchEvent(new CustomEvent('itemselected', { detail }));
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
    return this.items[index].suggestion.type;
  }

  showForElement(targetElement: HTMLElement) {
    if (!targetElement.isConnected || this.items.length === 0) {
      // Hide the popup because there are no suggestions to show. We have to do it
      // explicitly, because a border is still rendered even for an empty popup.
      // Also don't attempt to show the popup for disconnected node. Otherwise, it
      // will be shown out of place.
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

  onItemSelected(callback: (event: ItemSelection) => void) {
    this.container.addEventListener('itemselected', event => {
      callback(event.detail);
    });
  }

  onHistoryItemDeleteClicked(callback: (detail: HistoryItemDeleteDetail) => void) {
    this.container.addEventListener('historyitemdelete', event => {
      callback(event.detail);
    });
  }
}
