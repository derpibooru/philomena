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
    this.formatVersion = this.view.getUint32(backingStore.byteLength - 12, true);

    if (this.formatVersion !== 1) {
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
   * @returns {Result}
   */
  getResultAt(i) {
    const nameLocation = this.view.getUint32(this.referenceStart + i * 8, true);
    const imageCount = this.view.getUint32(this.referenceStart + i * 8 + 4, true);
    const [ name, associations ] = this.getTagFromLocation(nameLocation);

    return { name, imageCount, associations };
  }

  /**
   * Find the top k results by image count which match the given string prefix.
   *
   * @param {string} prefix
   * @param {number} k
   * @returns {Result[]}
   */
  topK(prefix, k) {
    /** @type {Result[]} */
    const results = [];

    /** @type {number[]} */
    //@ts-expect-error No type for window.booru yet
    const hiddenTags = window.booru.hiddenTagList;

    if (prefix === '') {
      return results;
    }

    // Binary search to find last smaller prefix
    let l = 0;
    let r = this.numTags;

    while (l < r - 1) {
      const m = (l + (r - l) / 2) | 0;
      const { name } = this.getResultAt(m);

      if (name.slice(0, prefix.length) >= prefix) {
        // too large, go left
        r = m;
      }
      else {
        // too small, go right
        l = m;
      }
    }

    // Scan forward until no more matches occur
    while (l < this.numTags - 1) {
      const result = this.getResultAt(++l);
      if (!result.name.startsWith(prefix)) {
        break;
      }

      // Add if no associations are filtered
      if (hiddenTags.findIndex(ht => result.associations.includes(ht)) === -1) {
        results.push(result);
      }
    }

    // Sort results by image count
    results.sort((a, b) => b.imageCount - a.imageCount);

    return results.slice(0, k);
  }
}
