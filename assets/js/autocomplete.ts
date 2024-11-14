/**
 * Autocomplete.
 */

import { LocalAutocompleter } from './utils/local-autocompleter';
import { getTermContexts } from './match_query';
import store from './utils/store';
import { TermContext } from './query/lex';
import { $$ } from './utils/dom';
import { fetchLocalAutocomplete, fetchSuggestions, SuggestionsPopup, TermSuggestion } from './utils/suggestions';

let inputField: HTMLInputElement | null = null,
  originalTerm: string | undefined,
  originalQuery: string | undefined,
  selectedTerm: TermContext | null = null;

const popup = new SuggestionsPopup();

function isSearchField(targetInput: HTMLElement): boolean {
  return targetInput && targetInput.dataset.acMode === 'search';
}

function restoreOriginalValue() {
  if (!inputField) return;

  if (isSearchField(inputField) && originalQuery) {
    inputField.value = originalQuery;
    return;
  }

  if (originalTerm) {
    inputField.value = originalTerm;
  }
}

function applySelectedValue(selection: string) {
  if (!inputField) return;

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

function findSelectedTerm(targetInput: HTMLInputElement, searchQuery: string): TermContext | null {
  if (targetInput.selectionStart === null || targetInput.selectionEnd === null) return null;

  const selectionIndex = Math.min(targetInput.selectionStart, targetInput.selectionEnd);
  const terms = getTermContexts(searchQuery);

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
  let serverSideSuggestionsTimeout: number | undefined;

  let localAc: LocalAutocompleter | null = null;
  let isLocalLoading = false;

  document.addEventListener('focusin', loadAutocompleteFromEvent);

  document.addEventListener('input', event => {
    popup.hide();
    loadAutocompleteFromEvent(event);
    window.clearTimeout(serverSideSuggestionsTimeout);

    if (!(event.target instanceof HTMLInputElement)) return;

    const targetedInput = event.target;

    if (!targetedInput.dataset.ac) return;

    targetedInput.addEventListener('keydown', keydownHandler);

    if (localAc !== null) {
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
        originalTerm = `${inputField.value}`.toLowerCase();
      }

      const suggestions = localAc
        .matchPrefix(originalTerm)
        .topK(suggestionsCount)
        .map(({ name, imageCount }) => ({ label: `${name} (${imageCount})`, value: name }));

      if (suggestions.length) {
        popup.renderSuggestions(suggestions).showForField(targetedInput);
        return;
      }
    }

    const { acMinLength: minTermLength, acSource: endpointUrl } = targetedInput.dataset;

    if (!endpointUrl) return;

    // Use a timeout to delay requests until the user has stopped typing
    serverSideSuggestionsTimeout = window.setTimeout(() => {
      inputField = targetedInput;
      originalTerm = inputField.value;

      const fetchedTerm = inputField.value;

      if (minTermLength && fetchedTerm.length < parseInt(minTermLength, 10)) return;

      fetchSuggestions(endpointUrl, fetchedTerm).then(suggestions => {
        // inputField could get overwritten while the suggestions are being fetched - use previously targeted input
        if (fetchedTerm === targetedInput.value) {
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

  function loadAutocompleteFromEvent(event: Event) {
    if (!(event.target instanceof HTMLInputElement)) return;

    if (!isLocalLoading && event.target.dataset.ac) {
      isLocalLoading = true;

      fetchLocalAutocomplete().then(autocomplete => {
        localAc = autocomplete;
      });
    }
  }

  toggleSearchAutocomplete();

  popup.onItemSelected((event: CustomEvent<TermSuggestion>) => {
    if (!event.detail || !inputField) return;

    const originalSuggestion = event.detail;
    applySelectedValue(originalSuggestion.value);

    inputField.dispatchEvent(
      new CustomEvent('autocomplete', {
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

export { listenAutocomplete };
