/**
 * Autocomplete.
 */

import { LocalAutocompleter } from 'utils/local-autocompleter';
import { handleError } from 'utils/requests';

const cache = {};
let inputField, originalTerm;

function removeParent() {
  const parent = document.querySelector('.autocomplete');
  if (parent) parent.parentNode.removeChild(parent);
}

function removeSelected() {
  const selected = document.querySelector('.autocomplete__item--selected');
  if (selected) selected.classList.remove('autocomplete__item--selected');
}

function changeSelected(firstOrLast, current, sibling) {
  if (current && sibling) { // if the currently selected item has a sibling, move selection to it
    current.classList.remove('autocomplete__item--selected');
    sibling.classList.add('autocomplete__item--selected');
  }
  else if (current) { // if the next keypress will take the user outside the list, restore the unautocompleted term
    inputField.value = originalTerm;
    removeSelected();
  }
  else if (firstOrLast) { // if no item in the list is selected, select the first or last
    firstOrLast.classList.add('autocomplete__item--selected');
  }
}

function keydownHandler(event) {
  const selected = document.querySelector('.autocomplete__item--selected'),
        firstItem = document.querySelector('.autocomplete__item:first-of-type'),
        lastItem = document.querySelector('.autocomplete__item:last-of-type');

  if (event.keyCode === 38) changeSelected(lastItem, selected, selected && selected.previousSibling); // ArrowUp
  if (event.keyCode === 40) changeSelected(firstItem, selected, selected && selected.nextSibling); // ArrowDown
  if (event.keyCode === 13 || event.keyCode === 27 || event.keyCode === 188) removeParent(); // Enter || Esc || Comma
  if (event.keyCode === 38 || event.keyCode === 40) { // ArrowUp || ArrowDown
    const newSelected = document.querySelector('.autocomplete__item--selected');
    if (newSelected) inputField.value = newSelected.dataset.value;
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
    inputField.value = item.dataset.value;
    inputField.dispatchEvent(
      new CustomEvent('autocomplete', {
        detail: {
          type: 'click',
          label: suggestion.label,
          value: suggestion.value,
        }
      })
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
  return fetch(`${inputField.dataset.acSource}${term}`).then(response => response.json());
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

    if (localAc !== null && 'ac' in event.target.dataset) {
      inputField = event.target;
      originalTerm = `${inputField.value}`.toLowerCase();

      const suggestions = localAc.topK(originalTerm, 5).map(({ name, imageCount }) => ({ label: `${name} (${imageCount})`, value: name }));
      return showAutocomplete(suggestions, originalTerm, event.target);
    }

    window.clearTimeout(timeout);
    // Use a timeout to delay requests until the user has stopped typing
    timeout = window.setTimeout(() => {
      inputField = event.target;
      originalTerm = inputField.value;

      const fetchedTerm = inputField.value;
      const {ac, acMinLength} = inputField.dataset;

      if (ac && (fetchedTerm.length >= acMinLength)) {
        if (cache[fetchedTerm]) {
          showAutocomplete(cache[fetchedTerm], fetchedTerm, event.target);
        }
        else {
          // inputField could get overwritten while the suggestions are being fetched - use event.target
          getSuggestions(fetchedTerm).then(suggestions => showAutocomplete(suggestions, fetchedTerm, event.target));
        }
      }
    }, 300);
  });

  // If there's a click outside the inputField, remove autocomplete
  document.addEventListener('click', event => {
    if (event.target && event.target !== inputField) removeParent();
  });

  function fetchLocalAutocomplete(event) {
    if (!localFetched && event.target.dataset && 'ac' in event.target.dataset) {
      localFetched = true;
      fetch('/autocomplete/compiled', { credentials: 'omit', cache: 'force-cache' })
        .then(handleError)
        .then(resp => resp.arrayBuffer())
        .then(buf => localAc = new LocalAutocompleter(buf));
    }
  }
}

export { listenAutocomplete };
