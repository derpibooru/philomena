import { makeEl } from './dom.ts';
import { mouseMoveThenOver } from './events.ts';
import { handleError } from './requests.ts';
import { LocalAutocompleter, Result } from './local-autocompleter.ts';

export interface TermSuggestion {
  label: string;
  value: string;
}

const selectedSuggestionClassName = 'autocomplete__item--selected';

export class SuggestionsPopup {
  private readonly container: HTMLElement;
  private readonly listElement: HTMLUListElement;
  private selectedElement: HTMLElement | null = null;

  constructor() {
    this.container = makeEl('div', {
      className: 'autocomplete',
    });

    this.listElement = makeEl('ul', {
      className: 'autocomplete__list',
    });

    this.container.appendChild(this.listElement);
  }

  get selectedTerm(): string | null {
    return this.selectedElement?.dataset.value || null;
  }

  get isActive(): boolean {
    return this.container.isConnected;
  }

  hide() {
    this.clearSelection();
    this.container.remove();
  }

  private clearSelection() {
    if (!this.selectedElement) return;

    this.selectedElement.classList.remove(selectedSuggestionClassName);
    this.selectedElement = null;
  }

  private updateSelection(targetItem: HTMLElement) {
    this.clearSelection();

    this.selectedElement = targetItem;
    this.selectedElement.classList.add(selectedSuggestionClassName);
  }

  renderSuggestions(suggestions: TermSuggestion[]): SuggestionsPopup {
    this.clearSelection();

    this.listElement.innerHTML = '';

    for (const suggestedTerm of suggestions) {
      const listItem = makeEl('li', {
        className: 'autocomplete__item',
        innerText: suggestedTerm.label,
      });

      listItem.dataset.value = suggestedTerm.value;

      this.watchItem(listItem, suggestedTerm);
      this.listElement.appendChild(listItem);
    }

    return this;
  }

  private watchItem(listItem: HTMLElement, suggestion: TermSuggestion) {
    // This makes sure the item isn't selected if the mouse pointer happens to
    // be right on top of the item when the list is rendered. So, the item may
    // only be selected on the first `mousemove` event occurring on the element.
    // See more details about this problem in the PR description:
    // https://github.com/philomena-dev/philomena/pull/350
    mouseMoveThenOver(listItem, () => this.updateSelection(listItem));

    listItem.addEventListener('mouseout', () => this.clearSelection());

    listItem.addEventListener('click', () => {
      if (!listItem.dataset.value) {
        return;
      }

      this.container.dispatchEvent(new CustomEvent('item_selected', { detail: suggestion }));
    });
  }

  private changeSelection(direction: number) {
    let nextTargetElement: Element | null;

    if (!this.selectedElement) {
      nextTargetElement = direction > 0 ? this.listElement.firstElementChild : this.listElement.lastElementChild;
    } else {
      nextTargetElement =
        direction > 0 ? this.selectedElement.nextElementSibling : this.selectedElement.previousElementSibling;
    }

    if (!(nextTargetElement instanceof HTMLElement)) {
      this.clearSelection();
      return;
    }

    this.updateSelection(nextTargetElement);
  }

  selectNext() {
    this.changeSelection(1);
  }

  selectPrevious() {
    this.changeSelection(-1);
  }

  showForField(targetElement: HTMLElement) {
    this.container.style.position = 'absolute';
    this.container.style.left = `${targetElement.offsetLeft}px`;

    let topPosition = targetElement.offsetTop + targetElement.offsetHeight;

    if (targetElement.parentElement) {
      topPosition -= targetElement.parentElement.scrollTop;
    }

    this.container.style.top = `${topPosition}px`;

    document.body.appendChild(this.container);
  }

  onItemSelected(callback: (event: CustomEvent<TermSuggestion>) => void) {
    this.container.addEventListener('item_selected', callback as EventListener);
  }
}

const cachedSuggestions = new Map<string, Promise<TermSuggestion[]>>();

export async function fetchSuggestions(endpoint: string, targetTerm: string): Promise<TermSuggestion[]> {
  const normalizedTerm = targetTerm.trim().toLowerCase();

  if (cachedSuggestions.has(normalizedTerm)) {
    return cachedSuggestions.get(normalizedTerm)!;
  }

  const promisedSuggestions: Promise<TermSuggestion[]> = fetch(`${endpoint}${targetTerm}`)
    .then(handleError)
    .then(response => response.json())
    .catch(() => {
      // Deleting the promised result from cache to allow retrying
      cachedSuggestions.delete(normalizedTerm);

      // And resolve failed promise with empty array
      return [];
    });

  cachedSuggestions.set(normalizedTerm, promisedSuggestions);

  return promisedSuggestions;
}

export function purgeSuggestionsCache() {
  cachedSuggestions.clear();
}

export async function fetchLocalAutocomplete(): Promise<LocalAutocompleter> {
  const now = new Date();
  const cacheKey = `${now.getUTCFullYear()}-${now.getUTCMonth()}-${now.getUTCDate()}`;

  return await fetch(`/autocomplete/compiled?vsn=2&key=${cacheKey}`, {
    credentials: 'omit',
    cache: 'force-cache',
  })
    .then(handleError)
    .then(resp => resp.arrayBuffer())
    .then(buf => new LocalAutocompleter(buf));
}

export function formatLocalAutocompleteResult(result: Result): TermSuggestion {
  let tagName = result.name;

  if (tagName !== result.aliasName) {
    tagName = `${result.aliasName} ⇒ ${tagName}`;
  }

  return {
    value: result.name,
    label: `${tagName} (${result.imageCount})`,
  };
}
