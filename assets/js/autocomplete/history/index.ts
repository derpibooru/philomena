import { HistorySuggestion } from '../../utils/suggestions';
import { InputHistory } from './history';
import { HistoryStore } from './store';
import { AutocompletableInput } from '../input';

/**
 * Stores a set of histories identified by their unique IDs.
 */
class InputHistoriesPool {
  private histories = new Map<string, InputHistory>();

  load(historyId: string): InputHistory {
    const existing = this.histories.get(historyId);

    if (existing) {
      return existing;
    }

    const store = new HistoryStore(historyId);
    const newHistory = new InputHistory(store);
    this.histories.set(historyId, newHistory);

    return newHistory;
  }
}

const histories = new InputHistoriesPool();

export function listen() {
  // Only load the history for the input element when it gets focused.
  document.addEventListener('focusin', event => {
    const input = AutocompletableInput.fromElement(event.target);

    if (!input?.historyId) {
      return;
    }

    histories.load(input.historyId);
  });

  document.addEventListener('submit', event => {
    if (!(event.target instanceof HTMLFormElement)) {
      return;
    }

    const input = [...event.target.elements]
      .map(elem => AutocompletableInput.fromElement(elem))
      .find(it => it !== null && it.hasHistory());

    if (!input) {
      return;
    }

    histories.load(input.historyId).write(input.snapshot.trimmedValue);
  });
}

/**
 * Returns suggestions based on history for the input. Unless the `limit` is
 * specified as an argument, it will return the maximum number of suggestions
 * allowed by the input.
 */
export function listSuggestions(input: AutocompletableInput, limit?: number): HistorySuggestion[] {
  if (!input.hasHistory()) {
    return [];
  }

  const value = input.snapshot.trimmedValue.toLowerCase();

  return histories
    .load(input.historyId)
    .listSuggestions(value, limit ?? input.maxSuggestions)
    .map(content => new HistorySuggestion(content, value.length));
}
