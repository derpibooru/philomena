// Client-side tag completion.
import { UniqueHeap } from './unique-heap';
import store from './store';

export interface Result {
  aliasName: string;
  name: string;
  imageCount: number;
  associations: number[];
}

/**
 * Returns whether Result a is considered less than Result b.
 */
function compareResult(a: Result, b: Result): boolean {
  return a.imageCount === b.imageCount ? a.name > b.name : a.imageCount < b.imageCount;
}

/**
 * Compare two strings, C-style.
 */
function strcmp(a: string, b: string): number {
  return a < b ? -1 : Number(a > b);
}

/**
 * Returns the name of a tag without any namespace component.
 */
function nameInNamespace(s: string): string {
  const first = s.indexOf(':');

  if (first !== -1) {
    return s.slice(first + 1);
  }

  return s;
}

/**
 * See lib/philomena/autocomplete.ex for binary structure details.
 *
 * A binary blob is used to avoid the creation of large amounts of garbage on
 * the JS heap and speed up the execution of the search.
 */
export class LocalAutocompleter {
  private data: Uint8Array;
  private view: DataView;
  private decoder: TextDecoder;
  private numTags: number;
  private referenceStart: number;
  private secondaryStart: number;
  private formatVersion: number;

  /**
   * Build a new local autocompleter.
   */
  constructor(backingStore: ArrayBuffer) {
    this.data = new Uint8Array(backingStore);
    this.view = new DataView(backingStore);
    this.decoder = new TextDecoder();
    this.numTags = this.view.getUint32(backingStore.byteLength - 4, true);
    this.referenceStart = this.view.getUint32(backingStore.byteLength - 8, true);
    this.secondaryStart = this.referenceStart + 8 * this.numTags;
    this.formatVersion = this.view.getUint32(backingStore.byteLength - 12, true);

    if (this.formatVersion !== 2) {
      throw new Error('Incompatible autocomplete format version');
    }
  }

  /**
   * Get a tag's name and its associations given a byte location inside the file.
   */
  private getTagFromLocation(location: number, imageCount: number, aliasName?: string): Result {
    const nameLength = this.view.getUint8(location);
    const assnLength = this.view.getUint8(location + 1 + nameLength);

    const associations: number[] = [];
    const name = this.decoder.decode(this.data.slice(location + 1, location + nameLength + 1));

    for (let i = 0; i < assnLength; i++) {
      associations.push(this.view.getUint32(location + 1 + nameLength + 1 + i * 4, true));
    }

    return { aliasName: aliasName || name, name, imageCount, associations };
  }

  /**
   * Get a Result object as the ith tag inside the file.
   */
  private getResultAt(i: number, aliasName?: string): Result {
    const tagLocation = this.view.getUint32(this.referenceStart + i * 8, true);
    const imageCount = this.view.getInt32(this.referenceStart + i * 8 + 4, true);
    const result = this.getTagFromLocation(tagLocation, imageCount, aliasName);

    if (imageCount < 0) {
      // This is actually an alias, so follow it
      return this.getResultAt(-imageCount - 1, aliasName || result.name);
    }

    return result;
  }

  /**
   * Get a Result object as the ith tag inside the file, secondary ordering.
   */
  private getSecondaryResultAt(i: number): Result {
    const referenceIndex = this.view.getUint32(this.secondaryStart + i * 4, true);
    return this.getResultAt(referenceIndex);
  }

  /**
   * Perform a binary search to fetch all results matching a condition.
   */
  private scanResults(
    getResult: (i: number) => Result,
    compare: (name: string) => number,
    results: UniqueHeap<Result>,
    hiddenTags: Set<number>,
  ) {
    const filter = !store.get('unfilter_tag_suggestions');

    let min = 0;
    let max = this.numTags;

    while (min < max - 1) {
      const med = min + (((max - min) / 2) | 0);
      const result = getResult(med);

      if (compare(result.aliasName) >= 0) {
        // too large, go left
        max = med;
      } else {
        // too small, go right
        min = med;
      }
    }

    // Scan forward until no more matches occur
    outer: while (min < this.numTags - 1) {
      const result = getResult(++min);

      if (compare(result.aliasName) !== 0) {
        break;
      }

      // Check if any associations are filtered
      if (filter) {
        for (const association of result.associations) {
          if (hiddenTags.has(association)) {
            continue outer;
          }
        }
      }

      // Nothing was filtered, so add
      results.append(result);
    }
  }

  /**
   * Find the top k results by image count which match the given string prefix.
   */
  matchPrefix(prefix: string): UniqueHeap<Result> {
    const results = new UniqueHeap<Result>(compareResult, 'name');

    if (prefix === '') {
      return results;
    }

    const hiddenTags = new Set(window.booru.hiddenTagList);

    // Find normally, in full name-sorted order
    const prefixMatch = (name: string) => strcmp(name.slice(0, prefix.length), prefix);
    this.scanResults(this.getResultAt.bind(this), prefixMatch, results, hiddenTags);

    // Find in secondary order
    const namespaceMatch = (name: string) => strcmp(nameInNamespace(name).slice(0, prefix.length), prefix);
    this.scanResults(this.getSecondaryResultAt.bind(this), namespaceMatch, results, hiddenTags);

    return results;
  }
}
