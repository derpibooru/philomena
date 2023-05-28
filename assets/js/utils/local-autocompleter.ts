// Client-side tag completion.
import store from './store';

interface Result {
  name: string;
  imageCount: number;
  associations: number[];
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
  const v = s.split(':', 2);

  if (v.length === 2) return v[1];
  return v[0];
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
  getTagFromLocation(location: number): [string, number[]] {
    const nameLength = this.view.getUint8(location);
    const assnLength = this.view.getUint8(location + 1 + nameLength);

    /** @type {number[]} */
    const associations = [];
    const name = this.decoder.decode(this.data.slice(location + 1, location + nameLength + 1));

    for (let i = 0; i < assnLength; i++) {
      associations.push(this.view.getUint32(location + 1 + nameLength + 1 + i * 4, true));
    }

    return [ name, associations ];
  }

  /**
   * Get a Result object as the ith tag inside the file.
   */
  getResultAt(i: number): [string, Result] {
    const nameLocation = this.view.getUint32(this.referenceStart + i * 8, true);
    const imageCount = this.view.getInt32(this.referenceStart + i * 8 + 4, true);
    const [ name, associations ] = this.getTagFromLocation(nameLocation);

    if (imageCount < 0) {
      // This is actually an alias, so follow it
      return [ name, this.getResultAt(-imageCount - 1)[1] ];
    }

    return [ name, { name, imageCount, associations } ];
  }

  /**
   * Get a Result object as the ith tag inside the file, secondary ordering.
   */
  getSecondaryResultAt(i: number): [string, Result] {
    const referenceIndex = this.view.getUint32(this.secondaryStart + i * 4, true);
    return this.getResultAt(referenceIndex);
  }

  /**
   * Perform a binary search to fetch all results matching a condition.
   */
  scanResults(getResult: (i: number) => [string, Result], compare: (name: string) => number, results: Record<string, Result>) {
    const unfilter = store.get('unfilter_tag_suggestions');

    let min = 0;
    let max = this.numTags;

    const hiddenTags = window.booru.hiddenTagList;

    while (min < max - 1) {
      const med = min + (max - min) / 2 | 0;
      const sortKey = getResult(med)[0];

      if (compare(sortKey) >= 0) {
        // too large, go left
        max = med;
      }
      else {
        // too small, go right
        min = med;
      }
    }

    // Scan forward until no more matches occur
    while (min < this.numTags - 1) {
      const [ sortKey, result ] = getResult(++min);
      if (compare(sortKey) !== 0) {
        break;
      }

      // Add if not filtering or no associations are filtered
      if (unfilter || hiddenTags.findIndex(ht => result.associations.includes(ht)) === -1) {
        results[result.name] = result;
      }
    }
  }

  /**
   * Find the top k results by image count which match the given string prefix.
   */
  topK(prefix: string, k: number): Result[] {
    const results: Record<string, Result> = {};

    if (prefix === '') {
      return [];
    }

    // Find normally, in full name-sorted order
    const prefixMatch = (name: string) => strcmp(name.slice(0, prefix.length), prefix);
    this.scanResults(this.getResultAt.bind(this), prefixMatch, results);

    // Find in secondary order
    const namespaceMatch = (name: string) => strcmp(nameInNamespace(name).slice(0, prefix.length), prefix);
    this.scanResults(this.getSecondaryResultAt.bind(this), namespaceMatch, results);

    // Sort results by image count
    const sorted = Object.values(results).sort((a, b) => b.imageCount - a.imageCount);

    return sorted.slice(0, k);
  }
}
