import { LocalAutocompleter } from '../utils/local-autocompleter';
import * as history from './history';
import { AutocompletableInput, TextInputElement } from './input';
import {
  SuggestionsPopup,
  Suggestions,
  TagSuggestion,
  Suggestion,
  HistorySuggestion,
  ItemSelectedEvent,
} from '../utils/suggestions';
import { $$ } from '../utils/dom';
import { AutocompleteClient, GetTagSuggestionsRequest } from './client';
import { DebouncedCache } from '../utils/debounced-cache';
import store from '../utils/store';

// This lint is dumb, especially in this case because this type alias depends on
// the `Autocomplete` symbol, and methods on the `Autocomplete` class depend on
// this type alias, so either way there is a circular dependency in type annotations
// eslint-disable-next-line no-use-before-define
type ActiveAutocomplete = Autocomplete & { input: AutocompletableInput };

function readHistoryConfig() {
  if (store.get<boolean>('autocomplete_search_history_hidden')) {
    return null;
  }

  return {
    maxSuggestionsWhenTyping: store.get<number>('autocomplete_search_history_max_suggestions_when_typing') ?? 3,
  };
}

class Autocomplete {
  index: null | 'fetching' | 'unavailable' | LocalAutocompleter = null;
  input: AutocompletableInput | null = null;
  popup = new SuggestionsPopup();
  client = new AutocompleteClient();
  serverSideTagSuggestions = new DebouncedCache(this.client.getTagSuggestions.bind(this.client));

  constructor() {
    this.popup.onItemSelected(this.confirmSuggestion.bind(this));
  }

  /**
   * Lazy-load the local autocomplete data.
   */
  async fetchLocalAutocomplete() {
    if (this.index) {
      // The index is already either fetching or initialized/unavailable, so nothing to do.
      return;
    }

    // Indicate that the index is in the process of fetching so that
    // we don't try to fetch it again while it's still loading.
    this.index = 'fetching';

    try {
      const index = await this.client.getCompiledAutocomplete();
      this.index = new LocalAutocompleter(index);
      this.refresh();
    } catch (error) {
      this.index = 'unavailable';
      console.error('Failed to fetch local autocomplete data', error);
    }
  }

  refresh() {
    this.serverSideTagSuggestions.abortLastSchedule('[Autocomplete] A new user input was received');

    this.input = AutocompletableInput.fromElement(document.activeElement);
    if (!this.isActive()) {
      this.popup.hide();
      return;
    }

    const { input } = this;

    // Initiate the lazy local autocomplete fetch on background if it hasn't been done yet.
    this.fetchLocalAutocomplete();

    const historyConfig = readHistoryConfig();

    // Show all history suggestions if the input is empty.
    if (historyConfig && input.snapshot.trimmedValue === '') {
      this.showSuggestions({
        history: history.listSuggestions(input),
        tags: [],
      });
      return;
    }

    // When the input is not empty the history suggestions take up
    // only a small portion of the suggestions.
    const suggestions: Suggestions = {
      history: historyConfig ? history.listSuggestions(input, historyConfig.maxSuggestionsWhenTyping) : [],
      tags: [],
    };

    // There are several scenarios where we don't try to fetch server-side suggestions,
    // even if we could.
    //
    // 1. The `index` is still `fetching`.
    //    We should wait until it's done. Doing concurrent server-side suggestions
    //    request in this case would be optimistically wasteful.
    //
    // 2. The `index` is `unavailable`.
    //    We shouldn't fetch server suggestions either because there may be something
    //    horribly wrong on the backend, so we don't want to spam it with even more
    //    requests. This scenario should be extremely rare though.
    if (
      !input.snapshot.activeTerm ||
      !(this.index instanceof LocalAutocompleter) ||
      suggestions.history.length === this.input.maxSuggestions
    ) {
      this.showSuggestions(suggestions);
      return;
    }

    const activeTerm = input.snapshot.activeTerm.term;

    suggestions.tags = this.index
      .matchPrefix(activeTerm, input.maxSuggestions - suggestions.history.length)
      .map(result => new TagSuggestion({ ...result, matchLength: activeTerm.length }));

    // Used for debugging server-side completions, to ensure local autocomplete
    // doesn't prevent sever-side completions from being shown. Use these console
    // commands to enable/disable server-side completions:
    // ```js
    // localStorage.setItem('SERVER_SIDE_COMPLETIONS_ONLY', true)
    // localStorage.removeItem('SERVER_SIDE_COMPLETIONS_ONLY')
    // ```
    if (store.get('SERVER_SIDE_COMPLETIONS_ONLY')) {
      suggestions.tags = [];
    }

    // Show suggestions that we already have early without waiting for a potential
    // server-side suggestions request.
    this.showSuggestions(suggestions);

    // Only if the index had its chance to provide suggestions
    // and produced nothing, do we try to fetch server-side suggestions.
    if (suggestions.tags.length > 0 || activeTerm.length < 3) {
      return;
    }

    this.scheduleServerSideSuggestions(activeTerm, suggestions.history);
  }

  scheduleServerSideSuggestions(this: ActiveAutocomplete, term: string, historySuggestions: HistorySuggestion[]) {
    const request: GetTagSuggestionsRequest = {
      term,

      // We always use the `maxSuggestions` value for the limit, because it's a
      // reasonably small and limited value. Yes, we may overfetch in some cases,
      // but otherwise the cache hits rate of `DebouncedCache` also increases due
      // to the less variation in the cache key (request params).
      limit: this.input.maxSuggestions,
    };

    this.serverSideTagSuggestions.schedule(request, response => {
      if (!this.isActive()) {
        return;
      }

      // Truncate the suggestions to the leftover space shared with history suggestions.
      const maxTags = this.input.maxSuggestions - historySuggestions.length;

      const tags = response.suggestions.slice(0, maxTags).map(
        suggestion =>
          new TagSuggestion({
            ...suggestion,
            matchLength: term.length,
          }),
      );

      this.showSuggestions({
        history: historySuggestions,
        tags,
      });
    });
  }

  showSuggestions(this: ActiveAutocomplete, suggestions: Suggestions) {
    this.popup.setSuggestions(suggestions).showForElement(this.input.element);
  }

  onFocusIn() {
    // The purpose of `focusin` subscription is to bring up the popup with the
    // initial history suggestions if there is no popup yet. If there is a popup
    // already, e.g. when we are re-focusing back to the input after the user
    // selected some suggestion then there is no need to refresh the popup.
    if (!this.popup.isHidden) {
      return;
    }

    // The event we are processing comes before the input's selection is updated.
    // Defer the refresh to the next frame to get the updated selection.
    requestAnimationFrame(() => {
      // Double-check the popup is still hidden on a new spin of the event loop.
      // Just in case =)
      if (!this.popup.isHidden) {
        return;
      }

      this.refresh();
    });
  }

  onClick(event: MouseEvent) {
    if (this.input?.isEnabled() && this.input.element !== event.target) {
      // We lost focus. Hide the popup.
      // We use this method instead of the `focusout` event because this way it's
      // easier to work in the developer tools when you want to inspect the element.
      // When you inspect it, a `focusout` happens.
      this.popup.hide();
      this.input = null;
    }
  }

  onKeyDown(event: KeyboardEvent) {
    if (!this.isActive() || this.input.element !== event.target) {
      return;
    }
    if ((event.key === ',' || event.code === 'Enter') && this.input.type === 'single-tag') {
      // Coma means the end of input for the current tag in single-tag mode.
      this.popup.hide();
      return;
    }

    switch (event.code) {
      case 'Enter': {
        const { selectedSuggestion } = this.popup;
        if (!selectedSuggestion) {
          return;
        }

        // Prevent submission of the form when Enter was hit.
        // Note, however, that `confirmSuggestion` may still submit the form
        // manually if the selected suggestion is a history suggestion and
        // no `Shift` key was pressed.
        event.preventDefault();

        this.confirmSuggestion({
          suggestion: selectedSuggestion,
          shiftKey: event.shiftKey,
          ctrlKey: event.ctrlKey,
        });
        return;
      }
      case 'Escape': {
        this.popup.hide();
        return;
      }
      case 'ArrowLeft':
      case 'ArrowRight': {
        // The event we are processing comes before the input's selection is updated.
        // Defer the refresh to the next frame to get the updated selection.
        requestAnimationFrame(() => this.refresh());
        return;
      }
      case 'ArrowUp':
      case 'ArrowDown': {
        if (event.code === 'ArrowUp') {
          if (event.ctrlKey) {
            this.popup.selectCtrlUp();
          } else {
            this.popup.selectUp();
          }
        } else {
          if (event.ctrlKey) {
            this.popup.selectCtrlDown();
          } else {
            this.popup.selectDown();
          }
        }

        if (this.popup.selectedSuggestion) {
          this.updateInputWithSelectedValue(this.popup.selectedSuggestion);
        } else {
          this.updateInputWithOriginalValue();
        }

        // Prevent the cursor from moving to the start or end of the input field,
        // which is the default behavior of the arrow keys are used in a text input.
        event.preventDefault();

        return;
      }
      default:
    }
  }

  updateInputWithOriginalValue(this: ActiveAutocomplete) {
    const { element, snapshot } = this.input;
    const { selection } = snapshot;
    element.value = snapshot.origValue;
    element.setSelectionRange(selection.start, selection.end, selection.direction ?? undefined);
  }

  confirmSuggestion({ suggestion, shiftKey, ctrlKey }: ItemSelectedEvent) {
    this.assertActive();

    this.updateInputWithSelectedValue(suggestion);

    const prefix = this.input.snapshot.activeTerm?.prefix ?? '';

    const detail = `${prefix}${suggestion.value()}`;

    const newEvent = new CustomEvent<string>('autocomplete', { detail });

    this.input.element.dispatchEvent(newEvent);

    if (ctrlKey || (suggestion instanceof HistorySuggestion && !shiftKey)) {
      // We use `requestSubmit()` instead of `submit()` because it triggers the
      // 'submit' event on the form. We have a handler subscribed to that event
      // that records the input's value for history tracking.
      this.input.element.form?.requestSubmit();
    }

    // XXX: it's important to focus the input element first before hiding the popup,
    // because if we do it the other way around our `onFocusIn` handler will refresh
    // the popup and bring it back up, which is not what we want. We want to give a
    // brief moment of silence for the user without the popup before they type
    // something else, otherwise we'd show some more completions for the current term.
    this.input.element.focus();
    this.popup.hide();
  }

  updateInputWithSelectedValue(this: ActiveAutocomplete, suggestion: Suggestion) {
    const {
      element,
      snapshot: { activeTerm, origValue },
    } = this.input;

    const value = suggestion.value();

    if (!activeTerm || suggestion instanceof HistorySuggestion) {
      element.value = value;
      return;
    }

    const { range, prefix } = activeTerm;

    element.value = origValue.slice(0, range.start) + prefix + value + origValue.slice(range.end);

    const newCursorIndex = range.start + value.length;
    element.setSelectionRange(newCursorIndex, newCursorIndex);
  }

  isActive(): this is ActiveAutocomplete {
    return Boolean(this.input?.isEnabled());
  }

  assertActive(): asserts this is ActiveAutocomplete {
    if (this.isActive()) {
      return;
    }

    console.debug('Current input when the error happened', this.input);
    throw new Error(`BUG: expected autocomplete to be active, but it isn't`);
  }
}

/**
 * Our custom autocomplete isn't compatible with the native browser autocomplete,
 * so we have to turn it off if our autocomplete is enabled, or turn it back on
 * if it's disabled.
 */
function refreshNativeAutocomplete() {
  const elements = $$<TextInputElement>(
    'input[data-autocomplete][data-autocomplete-condition], ' +
      'textarea[data-autocomplete][data-autocomplete-condition]',
  );

  for (const element of elements) {
    const input = AutocompletableInput.fromElement(element);
    if (!input) {
      continue;
    }

    element.autocomplete = input.isEnabled() ? 'off' : 'on';
  }
}

export function listenAutocomplete() {
  history.listen();

  const autocomplete = new Autocomplete();

  // Refresh all the state in case any autocomplete settings change.
  store.watchAll(key => {
    if (key && key !== 'enable_search_ac' && !key.startsWith('autocomplete')) {
      return;
    }

    refreshNativeAutocomplete();
    autocomplete.refresh();
  });

  refreshNativeAutocomplete();

  // By the time this script loads, the input elements may already be focused,
  // so we refresh the autocomplete state immediately to trigger the initial completions.
  autocomplete.refresh();

  document.addEventListener('focusin', autocomplete.onFocusIn.bind(autocomplete));
  document.addEventListener('input', autocomplete.refresh.bind(autocomplete));
  document.addEventListener('click', autocomplete.onClick.bind(autocomplete));
  document.addEventListener('keydown', autocomplete.onKeyDown.bind(autocomplete));
}
