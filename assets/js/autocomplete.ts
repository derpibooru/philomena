/**
 * Autocomplete.
 */

import { LocalAutocompleter } from './utils/local-autocompleter';
import { handleError } from './utils/requests';
import { getTermContexts } from './match_query';
import store from './utils/store';
import { TermContext } from './query/lex.ts';
import { $, $$, makeEl, removeEl } from './utils/dom.ts';

type TermSuggestion = {
  label: string;
  value: string;
};

const cachedSuggestions: Record<string, TermSuggestion[]> = {};
let inputField: HTMLInputElement | null = null,
  originalTerm: string | undefined,
  originalQuery: string | undefined,
  selectedTerm: TermContext | null = null;

function removeParent() {
  const parent = $<HTMLElement>('.autocomplete');
  if (parent) removeEl(parent);
}

function removeSelected() {
  const selected = $<HTMLElement>('.autocomplete__item--selected');
  if (selected) selected.classList.remove('autocomplete__item--selected');
}

function isSearchField(targetInput: HTMLElement): boolean {
  return targetInput && targetInput.dataset.acMode === 'search';
}

function restoreOriginalValue() {
  if (!inputField) {
    return;
  }

  if (isSearchField(inputField) && originalQuery) {
    inputField.value = originalQuery;
  }

  if (originalTerm) {
    inputField.value = originalTerm;
  }
}

function applySelectedValue(selection: string) {
  if (!inputField) {
    return;
  }

  if (!isSearchField(inputField)) {
    inputField.value = selection;
    return;
  }

  if (selectedTerm && originalQuery) {
    const [startIndex, endIndex] = selectedTerm[0];
    inputField.value = originalQuery.slice(0, startIndex) + selection + originalQuery.slice(endIndex);
    inputField.setSelectionRange(startIndex + selection.length, startIndex + selection.length);
    inputField.focus();
  }
}

function changeSelected(firstOrLast: Element | null, current: Element | null, sibling: Element | null) {
  if (current && sibling) {
    // if the currently selected item has a sibling, move selection to it
    current.classList.remove('autocomplete__item--selected');
    sibling.classList.add('autocomplete__item--selected');
  } else if (current) {
    // if the next keypress will take the user outside the list, restore the unautocompleted term
    restoreOriginalValue();
    removeSelected();
  } else if (firstOrLast) {
    // if no item in the list is selected, select the first or last
    firstOrLast.classList.add('autocomplete__item--selected');
  }
}

function isSelectionOutsideCurrentTerm(): boolean {
  if (!inputField || !selectedTerm) return true;
  if (inputField.selectionStart === null || inputField.selectionEnd === null) return true;

  const selectionIndex = Math.min(inputField.selectionStart, inputField.selectionEnd);
  const [startIndex, endIndex] = selectedTerm[0];

  return startIndex > selectionIndex || endIndex < selectionIndex;
}

function keydownHandler(event: KeyboardEvent) {
  const selected = $<HTMLElement>('.autocomplete__item--selected'),
    firstItem = $<HTMLElement>('.autocomplete__item:first-of-type'),
    lastItem = $<HTMLElement>('.autocomplete__item:last-of-type');

  if (inputField && isSearchField(inputField)) {
    // Prevent submission of the search field when Enter was hit
    if (selected && event.keyCode === 13) event.preventDefault(); // Enter

    // Close autocompletion popup when text cursor is outside current tag
    if (selectedTerm && firstItem && (event.keyCode === 37 || event.keyCode === 39)) {
      // ArrowLeft || ArrowRight
      requestAnimationFrame(() => {
        if (isSelectionOutsideCurrentTerm()) removeParent();
      });
    }
  }

  if (event.keyCode === 38) changeSelected(lastItem, selected, selected && selected.previousElementSibling); // ArrowUp
  if (event.keyCode === 40) changeSelected(firstItem, selected, selected && selected.nextElementSibling); // ArrowDown
  if (event.keyCode === 13 || event.keyCode === 27 || event.keyCode === 188) removeParent(); // Enter || Esc || Comma
  if (event.keyCode === 38 || event.keyCode === 40) {
    // ArrowUp || ArrowDown
    const newSelected = $<HTMLElement>('.autocomplete__item--selected');
    if (newSelected?.dataset.value) applySelectedValue(newSelected.dataset.value);
    event.preventDefault();
  }
}

function createItem(list: HTMLUListElement, suggestion: TermSuggestion) {
  const item = makeEl('li', {
    className: 'autocomplete__item',
  });

  let ignoreMouseOver = true;

  item.textContent = suggestion.label;
  item.dataset.value = suggestion.value;

  item.addEventListener('mouseover', () => {
    // Prevent selection when mouse entered the element without actually moving.
    if (ignoreMouseOver) {
      return;
    }

    removeSelected();
    item.classList.add('autocomplete__item--selected');
  });

  item.addEventListener('mouseout', () => {
    removeSelected();
  });

  item.addEventListener(
    'mousemove',
    () => {
      ignoreMouseOver = false;
      item.dispatchEvent(new CustomEvent('mouseover'));
    },
    {
      once: true,
    },
  );

  item.addEventListener('click', () => {
    if (!inputField || !item.dataset.value) return;

    applySelectedValue(item.dataset.value);

    inputField.dispatchEvent(
      new CustomEvent('autocomplete', {
        detail: {
          type: 'click',
          label: suggestion.label,
          value: suggestion.value,
        },
      }),
    );
  });

  list.appendChild(item);
}

function createList(parentElement: HTMLElement, suggestions: TermSuggestion[]) {
  const list = makeEl('ul', {
    className: 'autocomplete__list',
  });

  suggestions.forEach(suggestion => createItem(list, suggestion));

  parentElement.appendChild(list);
}

function createParent(): HTMLElement {
  const parent = makeEl('div');
  parent.className = 'autocomplete';

  if (inputField && inputField.parentElement) {
    // Position the parent below the inputfield
    parent.style.position = 'absolute';
    parent.style.left = `${inputField.offsetLeft}px`;
    // Take the inputfield offset, add its height and subtract the amount by which the parent element has scrolled
    parent.style.top = `${inputField.offsetTop + inputField.offsetHeight - inputField.parentElement.scrollTop}px`;
  }

  // We append the parent at the end of body
  document.body.appendChild(parent);

  return parent;
}

function showAutocomplete(suggestions: TermSuggestion[], fetchedTerm: string, targetInput: HTMLInputElement) {
  // Remove old autocomplete suggestions
  removeParent();

  // Save suggestions in cache
  cachedSuggestions[fetchedTerm] = suggestions;

  // If the input target is not empty, still visible, and suggestions were found
  if (targetInput.value && targetInput.style.display !== 'none' && suggestions.length) {
    createList(createParent(), suggestions);
    targetInput.addEventListener('keydown', keydownHandler);
  }
}

async function getSuggestions(term: string): Promise<TermSuggestion[]> {
  // In case source URL was not given at all, do not try sending the request.
  if (!inputField?.dataset.acSource) return [];

  return await fetch(`${inputField.dataset.acSource}${term}`)
    .then(handleError)
    .then(response => response.json());
}

function getSelectedTerm(): TermContext | null {
  if (!inputField || !originalQuery) return null;
  if (inputField.selectionStart === null || inputField.selectionEnd === null) return null;

  const selectionIndex = Math.min(inputField.selectionStart, inputField.selectionEnd);
  const terms = getTermContexts(originalQuery);

  return terms.find(([range]) => range[0] < selectionIndex && range[1] >= selectionIndex) ?? null;
}

function toggleSearchAutocomplete() {
  const enable = store.get('enable_search_ac');

  for (const searchField of $$<HTMLInputElement>('input[data-ac-mode=search]')) {
    if (enable) {
      searchField.autocomplete = 'off';
    } else {
      searchField.removeAttribute('data-ac');
      searchField.autocomplete = 'on';
    }
  }
}

function listenAutocomplete() {
  let timeout: number | undefined;

  let localAc: LocalAutocompleter | null = null;
  let localFetched = false;

  document.addEventListener('focusin', fetchLocalAutocomplete);

  document.addEventListener('input', event => {
    removeParent();
    fetchLocalAutocomplete(event);
    window.clearTimeout(timeout);

    if (!(event.target instanceof HTMLInputElement)) return;

    const targetedInput = event.target;

    if (localAc !== null && 'ac' in targetedInput.dataset) {
      inputField = targetedInput;
      let suggestionsCount = 5;

      if (isSearchField(inputField)) {
        originalQuery = inputField.value;
        selectedTerm = getSelectedTerm();
        suggestionsCount = 10;

        // We don't need to run auto-completion if user is not selecting tag at all
        if (!selectedTerm) {
          return;
        }

        originalTerm = selectedTerm[1].toLowerCase();
      } else {
        originalTerm = `${inputField.value}`.toLowerCase();
      }

      const suggestions = localAc
        .matchPrefix(originalTerm)
        .topK(suggestionsCount)
        .map(({ name, imageCount }) => ({ label: `${name} (${imageCount})`, value: name }));

      if (suggestions.length) {
        return showAutocomplete(suggestions, originalTerm, targetedInput);
      }
    }

    // Use a timeout to delay requests until the user has stopped typing
    timeout = window.setTimeout(() => {
      inputField = targetedInput;
      originalTerm = inputField.value;

      const fetchedTerm = inputField.value;
      const { ac, acMinLength, acSource } = inputField.dataset;

      if (!ac || !acSource || (acMinLength && fetchedTerm.length < parseInt(acMinLength, 10))) {
        return;
      }

      if (cachedSuggestions[fetchedTerm]) {
        showAutocomplete(cachedSuggestions[fetchedTerm], fetchedTerm, targetedInput);
      } else {
        // inputField could get overwritten while the suggestions are being fetched - use event.target
        getSuggestions(fetchedTerm).then(suggestions => {
          if (fetchedTerm === targetedInput.value) {
            showAutocomplete(suggestions, fetchedTerm, targetedInput);
          }
        });
      }
    }, 300);
  });

  // If there's a click outside the inputField, remove autocomplete
  document.addEventListener('click', event => {
    if (event.target && event.target !== inputField) removeParent();
    if (inputField && event.target === inputField && isSearchField(inputField) && isSelectionOutsideCurrentTerm()) {
      removeParent();
    }
  });

  function fetchLocalAutocomplete(event: Event) {
    if (!(event.target instanceof HTMLInputElement)) return;

    if (!localFetched && event.target.dataset && 'ac' in event.target.dataset) {
      const now = new Date();
      const cacheKey = `${now.getUTCFullYear()}-${now.getUTCMonth()}-${now.getUTCDate()}`;

      localFetched = true;

      fetch(`/autocomplete/compiled?vsn=2&key=${cacheKey}`, { credentials: 'omit', cache: 'force-cache' })
        .then(handleError)
        .then(resp => resp.arrayBuffer())
        .then(buf => {
          localAc = new LocalAutocompleter(buf);
        });
    }
  }

  toggleSearchAutocomplete();
}

export { listenAutocomplete };
