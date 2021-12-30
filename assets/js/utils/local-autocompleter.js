//@ts-check
/*
 * Client-side tag completion.
 */

/**
 * @typedef {object} Result
 * @property {string} name
 * @property {number} imageCount
 * @property {number[]} associations
 */

/**
 * Compare two strings, C-style.
 *
 * @param {string} a
 * @param {string} b
 * @returns {number}
 */
function strcmp(a, b) {
  return a < b ? -1 : Number(a > b);
}

/**
 * Returns the name of a tag without any namespace component.
 *
 * @param {string} s
 * @returns {string}
 */
function nameInNamespace(s) {
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
  /**
   * Build a new local autocompleter.
   *
   * @param {ArrayBuffer} backingStore
   */
  constructor(backingStore) {
    /** @type {Uint8Array} */
    this.data = new Uint8Array(backingStore);
    /** @type {DataView} */
    this.view = new DataView(backingStore);
    /** @type {TextDecoder} */
    this.decoder = new TextDecoder();
    /** @type {number} */
    this.numTags = this.view.getUint32(backingStore.byteLength - 4, true);
    /** @type {number} */
    this.referenceStart = this.view.getUint32(backingStore.byteLength - 8, true);
    /** @type {number} */
    this.secondaryStart = this.referenceStart + 8 * this.numTags;
    /** @type {number} */
    this.formatVersion = this.view.getUint32(backingStore.byteLength - 12, true);

    if (this.formatVersion !== 2) {
      throw new Error('Incompatible autocomplete format version');
    }
  }

  /**
   * Get a tag's name and its associations given a byte location inside the file.
   *
   * @param {number} location
   * @returns {[string, number[]]}
   */
  getTagFromLocation(location) {
    const nameLength = this.view.getUint8(location);
    const assnLength = this.view.getUint8(location + 1 + nameLength);

    /** @type {number[]} */
    const associations = [];
    const name = this.decoder.decode(this.data.slice(location + 1, location + nameLength + 1));

    for (let i = 0; i < assnLength; i++) {
      associations.push(this.view.getUint32(location + 1 + nameLength + i * 4, true));
    }

    return [ name, associations ];
  }

  /**
   * Get a Result object as the ith tag inside the file.
   *
   * @param {number} i
   * @returns {[string, Result]}
   */
  getResultAt(i) {
    const nameLocation = this.view.getUint32(this.referenceStart + i * 8, true);
    const imageCount = this.view.getInt32(this.referenceStart + i * 8 + 4, true);
    const [ name, associations ] = this.getTagFromLocation(nameLocation);

    if (imageCount < 0) {
      // This is actually an alias, so follow it
      return [ name, this.getResultAt(-imageCount)[1] ];
    }

    return [ name, { name, imageCount, associations } ];
  }

  /**
   * Get a Result object as the ith tag inside the file, secondary ordering.
   *
   * @param {number} i
   * @returns {[string, Result]}
   */
  getSecondaryResultAt(i) {
    const referenceIndex = this.view.getUint32(this.secondaryStart + i * 4, true);
    return this.getResultAt(referenceIndex);
  }

  /**
   * Perform a binary search to fetch all results matching a condition.
   *
   * @param {(i: number) => [string, Result]} getResult
   * @param {(name: string) => number} compare
   * @param {{[key: string]: Result}} results
   */
  scanResults(getResult, compare, results) {
    let min = 0;
    let max = this.numTags;

    /** @type {number[]} */
    //@ts-expect-error No type for window.booru yet
    const hiddenTags = window.booru.hiddenTagList;

    while (min < max - 1) {
      const med = (min + (max - min) / 2) | 0;
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

      // Add if no associations are filtered
      if (hiddenTags.findIndex(ht => result.associations.includes(ht)) === -1) {
        results[result.name] = result;
      }
    }
  }

  /**
   * Find the top k results by image count which match the given string prefix.
   *
   * @param {string} prefix
   * @param {number} k
   * @returns {Result[]}
   */
  topK(prefix, k) {
    /** @type {{[key: string]: Result}} */
    const results = {};

    if (prefix === '') {
      return [];
    }

    // Find normally, in full name-sorted order
    const prefixMatch = (/** @type {string} */ name) => strcmp(name.slice(0, prefix.length), prefix);
    this.scanResults(this.getResultAt.bind(this), prefixMatch, results);

    // Find in secondary order
    const namespaceMatch = (/** @type {string} */ name) => strcmp(nameInNamespace(name).slice(0, prefix.length), prefix);
    this.scanResults(this.getSecondaryResultAt.bind(this), namespaceMatch, results);

    // Sort results by image count
    const sorted = Object.values(results).sort((a, b) => b.imageCount - a.imageCount);

    return sorted.slice(0, k);
  }
}
