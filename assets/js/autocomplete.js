/**
 * Autocomplete.
 */

import { LocalAutocompleter } from './utils/local-autocompleter';
import { handleError } from './utils/requests';
import { getTermContexts } from './match_query';
import store from './utils/store';

const cache = {};
/** @type {HTMLInputElement} */
let inputField,
  /** @type {string} */
  originalTerm,
  /** @type {string} */
  originalQuery,
  /** @type {TermContext} */
  selectedTerm;

function removeParent() {
  const parent = document.querySelector('.autocomplete');
  if (parent) parent.parentNode.removeChild(parent);
}

function removeSelected() {
  const selected = document.querySelector('.autocomplete__item--selected');
  if (selected) selected.classList.remove('autocomplete__item--selected');
}

function isSearchField() {
  return inputField && inputField.dataset.acMode === 'search';
}

function restoreOriginalValue() {
  inputField.value = isSearchField() ? originalQuery : originalTerm;
}

function applySelectedValue(selection) {
  if (!isSearchField()) {
    inputField.value = selection;
    return;
  }

  if (!selectedTerm) {
    return;
  }

  const [startIndex, endIndex] = selectedTerm[0];
  inputField.value = originalQuery.slice(0, startIndex) + selection + originalQuery.slice(endIndex);
  inputField.setSelectionRange(startIndex + selection.length, startIndex + selection.length);
  inputField.focus();
}

function changeSelected(firstOrLast, current, sibling) {
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

function isSelectionOutsideCurrentTerm() {
  const selectionIndex = Math.min(inputField.selectionStart, inputField.selectionEnd);
  const [startIndex, endIndex] = selectedTerm[0];

  return startIndex > selectionIndex || endIndex < selectionIndex;
}

function keydownHandler(event) {
  const selected = document.querySelector('.autocomplete__item--selected'),
    firstItem = document.querySelector('.autocomplete__item:first-of-type'),
    lastItem = document.querySelector('.autocomplete__item:last-of-type');

  if (isSearchField()) {
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

  if (event.keyCode === 38) changeSelected(lastItem, selected, selected && selected.previousSibling); // ArrowUp
  if (event.keyCode === 40) changeSelected(firstItem, selected, selected && selected.nextSibling); // ArrowDown
  if (event.keyCode === 13 || event.keyCode === 27 || event.keyCode === 188) removeParent(); // Enter || Esc || Comma
  if (event.keyCode === 38 || event.keyCode === 40) {
    // ArrowUp || ArrowDown
    const newSelected = document.querySelector('.autocomplete__item--selected');
    if (newSelected) applySelectedValue(newSelected.dataset.value);
    event.preventDefault();
  }
}

function createItem(list, suggestion) {
  const item = document.createElement('li');
  item.className = 'autocomplete__item';

  item.textContent = suggestion.label;
  item.dataset.value = suggestion.value;

  item.addEventListener('mouseover', () => {
    removeSelected();
    item.classList.add('autocomplete__item--selected');
  });

  item.addEventListener('mouseout', () => {
    removeSelected();
  });

  item.addEventListener('click', () => {
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

function createList(suggestions) {
  const parent = document.querySelector('.autocomplete'),
    list = document.createElement('ul');
  list.className = 'autocomplete__list';

  suggestions.forEach(suggestion => createItem(list, suggestion));

  parent.appendChild(list);
}

function createParent() {
  const parent = document.createElement('div');
  parent.className = 'autocomplete';

  // Position the parent below the inputfield
  parent.style.position = 'absolute';
  parent.style.left = `${inputField.offsetLeft}px`;
  // Take the inputfield offset, add its height and subtract the amount by which the parent element has scrolled
  parent.style.top = `${inputField.offsetTop + inputField.offsetHeight - inputField.parentNode.scrollTop}px`;

  // We append the parent at the end of body
  document.body.appendChild(parent);
}

function showAutocomplete(suggestions, fetchedTerm, targetInput) {
  // Remove old autocomplete suggestions
  removeParent();

  // Save suggestions in cache
  cache[fetchedTerm] = suggestions;

  // If the input target is not empty, still visible, and suggestions were found
  if (targetInput.value && targetInput.style.display !== 'none' && suggestions.length) {
    createParent();
    createList(suggestions);
    inputField.addEventListener('keydown', keydownHandler);
  }
}

function getSuggestions(term) {
  // In case source URL was not given at all, do not try sending the request.
  if (!inputField.dataset.acSource) return [];
  return fetch(`${inputField.dataset.acSource}${term}`).then(response => response.json());
}

function getSelectedTerm() {
  if (!inputField || !originalQuery) {
    return null;
  }

  const selectionIndex = Math.min(inputField.selectionStart, inputField.selectionEnd);
  const terms = getTermContexts(originalQuery);

  return terms.find(([range]) => range[0] < selectionIndex && range[1] >= selectionIndex);
}

function toggleSearchAutocomplete() {
  const enable = store.get('enable_search_ac');

  for (const searchField of document.querySelectorAll('input[data-ac-mode=search]')) {
    if (enable) {
      searchField.autocomplete = 'off';
    } else {
      searchField.removeAttribute('data-ac');
      searchField.autocomplete = 'on';
    }
  }
}

function listenAutocomplete() {
  let timeout;

  /** @type {LocalAutocompleter} */
  let localAc = null;
  let localFetched = false;

  document.addEventListener('focusin', fetchLocalAutocomplete);

  document.addEventListener('input', event => {
    removeParent();
    fetchLocalAutocomplete(event);
    window.clearTimeout(timeout);

    if (localAc !== null && 'ac' in event.target.dataset) {
      inputField = event.target;
      let suggestionsCount = 5;

      if (isSearchField()) {
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
        .topK(originalTerm, suggestionsCount)
        .map(({ name, imageCount }) => ({ label: `${name} (${imageCount})`, value: name }));

      if (suggestions.length) {
        return showAutocomplete(suggestions, originalTerm, event.target);
      }
    }

    // Use a timeout to delay requests until the user has stopped typing
    timeout = window.setTimeout(() => {
      inputField = event.target;
      originalTerm = inputField.value;

      const fetchedTerm = inputField.value;
      const { ac, acMinLength, acSource } = inputField.dataset;

      if (ac && acSource && fetchedTerm.length >= acMinLength) {
        if (cache[fetchedTerm]) {
          showAutocomplete(cache[fetchedTerm], fetchedTerm, event.target);
        } else {
          // inputField could get overwritten while the suggestions are being fetched - use event.target
          getSuggestions(fetchedTerm).then(suggestions => {
            if (fetchedTerm === event.target.value) {
              showAutocomplete(suggestions, fetchedTerm, event.target);
            }
          });
        }
      }
    }, 300);
  });

  // If there's a click outside the inputField, remove autocomplete
  document.addEventListener('click', event => {
    if (event.target && event.target !== inputField) removeParent();
    if (event.target === inputField && isSearchField() && isSelectionOutsideCurrentTerm()) removeParent();
  });

  function fetchLocalAutocomplete(event) {
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
