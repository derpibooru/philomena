import { HistoryStore } from './store';

/**
 * Maximum number of records we keep in the history. If the limit is reached,
 * the least popular records will be removed to make space for new ones.
 */
const maxRecords = 1000;

/**
 * Maximum length of the input content we store in the history. If the input
 * exceeds this value it won't be saved in the history.
 */
const maxInputLength = 256;

/**
 * Input history is a mini DB limited in size and stored in the `localStorage`.
 * It provides a simple CRUD API for the search history data.
 *
 * Note that `localStorage` is not transactional. Other browser tabs may modify
 * it concurrently, which may lead to version mismatches and potential TOCTOU
 * issues. However, search history data is not critical, and the probability of
 * concurrent usage patterns is almost 0. The worst thing that can happen in
 * such a rare scenario is that a search query may not be saved to the storage
 * or the search history may be temporarily disabled for the current session
 * until the page is reloaded with a newer version of the frontend code.
 */
export class InputHistory {
  private readonly store: HistoryStore;

  /**
   * The list of history records sorted from the last recently used to the oldest unused.
   */
  private records: string[];

  constructor(store: HistoryStore) {
    this.store = store;

    const parsing = performance.now();
    this.records = store.read();

    const end = performance.now();
    console.debug(`Loading input history took ${end - parsing}ms. Records: ${this.records.length}.`);
  }

  /**
   * Save the input into the history and commit it to the `localStorage`.
   * Expects a value trimmed from whitespace by the caller.
   */
  write(input: string) {
    if (input === '') {
      return;
    }

    if (input.length > maxInputLength) {
      console.warn(`The input is too long to be saved in the search history (length: ${input.length}).`);
      return;
    }

    const index = this.records.findIndex(historyRecord => historyRecord === input);

    if (index >= 0) {
      this.records.splice(index, 1);
    } else if (this.records.length >= maxRecords) {
      // Bye-bye, the oldest unused record! 👋 Nopony will miss you 🔪🩸
      this.records.pop();
    }

    // Put the record on the top of the list as the last recently used.
    this.records.unshift(input);

    this.store.write(this.records);
  }

  listSuggestions(query: string, limit: number): string[] {
    // Waiting for iterator combinators such as `Iterator.prototype.filter()`
    // and `Iterator.prototype.take()` to reach a greater availability 🙏:
    // https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Iterator/filter
    // https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Iterator/take

    const results = [];

    for (const record of this.records) {
      if (results.length >= limit) {
        break;
      }

      if (record.startsWith(query)) {
        results.push(record);
      }
    }

    return results;
  }
}
