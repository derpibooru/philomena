/**
 * Autocomplete.
 */

import { LocalAutocompleter } from './utils/local-autocompleter';
import { getTermContexts } from './match_query';
import store from './utils/store';
import { TermContext } from './query/lex';
import { $$ } from './utils/dom';
import {
  formatLocalAutocompleteResult,
  fetchLocalAutocomplete,
  fetchSuggestions,
  SuggestionsPopup,
  TermSuggestion,
} from './utils/suggestions';

type AutocompletableInputElement = HTMLInputElement | HTMLTextAreaElement;

function hasAutocompleteEnabled(element: unknown): element is AutocompletableInputElement {
  return (
    (element instanceof HTMLInputElement || element instanceof HTMLTextAreaElement) &&
    Boolean(element.dataset.autocomplete)
  );
}

let inputField: AutocompletableInputElement | null = null;
let originalTerm: string | undefined;
let originalQuery: string | undefined;
let selectedTerm: TermContext | null = null;

const popup = new SuggestionsPopup();

function isSearchField(targetInput: HTMLElement): boolean {
  return targetInput.dataset.autocompleteMode === 'search';
}

function restoreOriginalValue() {
  if (!inputField) return;

  if (isSearchField(inputField) && originalQuery) {
    inputField.value = originalQuery;

    if (selectedTerm) {
      const [, selectedTermEnd] = selectedTerm[0];

      inputField.setSelectionRange(selectedTermEnd, selectedTermEnd);
    }

    return;
  }

  if (originalTerm) {
    inputField.value = originalTerm;
  }
}

function applySelectedValue(selection: string) {
  if (!inputField) return;

  if (!isSearchField(inputField)) {
    let resultValue = selection;

    if (originalTerm?.startsWith('-')) {
      resultValue = `-${selection}`;
    }

    inputField.value = resultValue;
    return;
  }

  if (selectedTerm && originalQuery) {
    const [startIndex, endIndex] = selectedTerm[0];
    inputField.value = originalQuery.slice(0, startIndex) + selection + originalQuery.slice(endIndex);
    inputField.setSelectionRange(startIndex + selection.length, startIndex + selection.length);
    inputField.focus();
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
  if (inputField !== event.currentTarget) return;

  if (inputField && isSearchField(inputField)) {
    // Prevent submission of the search field when Enter was hit
    if (popup.selectedTerm && event.keyCode === 13) event.preventDefault(); // Enter

    // Close autocompletion popup when text cursor is outside current tag
    if (selectedTerm && (event.keyCode === 37 || event.keyCode === 39)) {
      // ArrowLeft || ArrowRight
      requestAnimationFrame(() => {
        if (isSelectionOutsideCurrentTerm()) popup.hide();
      });
    }
  }

  if (!popup.isActive) return;

  if (event.keyCode === 38) popup.selectPrevious(); // ArrowUp
  if (event.keyCode === 40) popup.selectNext(); // ArrowDown
  if (event.keyCode === 13 || event.keyCode === 27 || event.keyCode === 188) popup.hide(); // Enter || Esc || Comma
  if (event.keyCode === 38 || event.keyCode === 40) {
    // ArrowUp || ArrowDown
    if (popup.selectedTerm) {
      applySelectedValue(popup.selectedTerm);
    } else {
      restoreOriginalValue();
    }

    event.preventDefault();
  }
}

function findSelectedTerm(targetInput: AutocompletableInputElement, searchQuery: string): TermContext | null {
  if (targetInput.selectionStart === null || targetInput.selectionEnd === null) return null;

  const selectionIndex = Math.min(targetInput.selectionStart, targetInput.selectionEnd);

  // Multi-line textarea elements should treat each line as the different search queries. Here we're looking for the
  // actively edited line and use it instead of the whole value.
  const activeLineStart = searchQuery.slice(0, selectionIndex).lastIndexOf('\n') + 1;
  const lengthAfterSelectionIndex = Math.max(searchQuery.slice(selectionIndex).indexOf('\n'), 0);
  const targetQuery = searchQuery.slice(activeLineStart, selectionIndex + lengthAfterSelectionIndex);

  const terms = getTermContexts(targetQuery);
  const searchIndex = selectionIndex - activeLineStart;
  const term = terms.find(([range]) => range[0] < searchIndex && range[1] >= searchIndex) ?? null;

  // Converting line-specific indexes back to absolute ones.
  if (term) {
    const [range] = term;

    range[0] += activeLineStart;
    range[1] += activeLineStart;
  }

  return term;
}

/**
 * Our custom autocomplete isn't compatible with the native browser autocomplete,
 * so we have to turn it off if our autocomplete is enabled, or turn it back on
 * if it's disabled.
 */
function toggleSearchNativeAutocomplete() {
  const enable = store.get('enable_search_ac');

  const searchFields = $$<AutocompletableInputElement>(
    ':is(input, textarea)[data-autocomplete][data-autocomplete-mode=search]',
  );

  for (const searchField of searchFields) {
    if (enable) {
      searchField.autocomplete = 'off';
    } else {
      searchField.removeAttribute('data-autocomplete');
      searchField.autocomplete = 'on';
    }
  }
}

function trimPrefixes(targetTerm: string): string {
  return targetTerm.trim().replace(/^-/, '');
}

/**
 * We control the autocomplete with `data-autocomplete*` attributes in HTML, and subscribe
 * event listeners to the `document`. This pattern is described in more detail
 * here: https://javascript.info/event-delegation
 */
export function listenAutocomplete() {
  let serverSideSuggestionsTimeout: number | undefined;

  let localAutocomplete: LocalAutocompleter | null = null;

  document.addEventListener('focusin', loadAutocompleteFromEvent);

  document.addEventListener('input', event => {
    popup.hide();
    loadAutocompleteFromEvent(event);
    window.clearTimeout(serverSideSuggestionsTimeout);

    if (!hasAutocompleteEnabled(event.target)) return;

    const targetedInput = event.target;

    targetedInput.addEventListener('keydown', keydownHandler as EventListener);

    if (localAutocomplete !== null) {
      inputField = targetedInput;
      let suggestionsCount = 5;

      if (isSearchField(inputField)) {
        originalQuery = inputField.value;
        selectedTerm = findSelectedTerm(inputField, originalQuery);
        suggestionsCount = 10;

        // We don't need to run auto-completion if user is not selecting tag at all
        if (!selectedTerm) {
          return;
        }

        originalTerm = selectedTerm[1].toLowerCase();
      } else {
        originalTerm = inputField.value.toLowerCase();
      }

      const suggestions = localAutocomplete
        .matchPrefix(trimPrefixes(originalTerm), suggestionsCount)
        .map(formatLocalAutocompleteResult);

      if (suggestions.length) {
        popup.renderSuggestions(suggestions).showForField(targetedInput);
        return;
      }
    }

    const { autocompleteMinLength: minTermLength, autocompleteSource: endpointUrl } = targetedInput.dataset;

    if (!endpointUrl) return;

    // Use a timeout to delay requests until the user has stopped typing
    serverSideSuggestionsTimeout = window.setTimeout(() => {
      inputField = targetedInput;
      originalTerm = inputField.value;

      const fetchedTerm = trimPrefixes(inputField.value);

      if (minTermLength && fetchedTerm.length < parseInt(minTermLength, 10)) return;

      fetchSuggestions(endpointUrl, fetchedTerm).then(suggestions => {
        // inputField could get overwritten while the suggestions are being fetched - use previously targeted input
        if (fetchedTerm === trimPrefixes(targetedInput.value)) {
          popup.renderSuggestions(suggestions).showForField(targetedInput);
        }
      });
    }, 300);
  });

  // If there's a click outside the inputField, remove autocomplete
  document.addEventListener('click', event => {
    if (event.target && event.target !== inputField) popup.hide();
    if (inputField && event.target === inputField && isSearchField(inputField) && isSelectionOutsideCurrentTerm()) {
      popup.hide();
    }
  });

  // Lazy-load the local autocomplete index from the server only once.
  let localAutocompleteFetchNeeded = true;

  async function loadAutocompleteFromEvent(event: Event) {
    if (!localAutocompleteFetchNeeded || !hasAutocompleteEnabled(event.target)) {
      return;
    }

    localAutocompleteFetchNeeded = false;
    localAutocomplete = await fetchLocalAutocomplete();
  }

  toggleSearchNativeAutocomplete();

  popup.onItemSelected((event: CustomEvent<TermSuggestion>) => {
    if (!event.detail || !inputField) return;

    const originalSuggestion = event.detail;
    applySelectedValue(originalSuggestion.value);

    if (originalTerm?.startsWith('-')) {
      originalSuggestion.value = `-${originalSuggestion.value}`;
    }

    inputField.dispatchEvent(
      new CustomEvent<TermSuggestion>('autocomplete', {
        detail: Object.assign(
          {
            type: 'click',
          },
          originalSuggestion,
        ),
      }),
    );
  });
}
