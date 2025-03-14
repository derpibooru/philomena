// Client-side tag completion.
import { UniqueHeap } from './unique-heap';
import store from './store';

export interface Result {
  /**
   * If present, then this suggestion is for a tag alias.
   * If absent, then this suggestion is for the `canonical` tag name.
   */
  alias?: null | string;

  /**
   * The canonical name of the tag (non-alias).
   */
  canonical: string;

  /**
   * Number of images tagged with this tag.
   */
  images: number;
}

/**
 * Opaque, unique pointer to tag data.
 */
type TagPointer = number;

/**
 * Numeric index of a tag in its primary order.
 */
type TagReferenceIndex = number;

/**
 * Compare two UTF-8 strings, C-style.
 */
function strcmp(a: Uint8Array, b: Uint8Array): number {
  const aLength = a.length;
  const bLength = b.length;
  let index = 0;

  while (index < aLength && index < bLength && a[index] === b[index]) {
    index++;
  }

  const aValue = index >= aLength ? 0 : a[index];
  const bValue = index >= bLength ? 0 : b[index];

  return aValue - bValue;
}

const namespaceSeparator = ':'.charCodeAt(0);

/**
 * Returns the name of a tag without any namespace component.
 */
function nameInNamespace(s: Uint8Array): Uint8Array {
  const first = s.indexOf(namespaceSeparator);

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
  private encoder: TextEncoder;
  private decoder: TextDecoder;
  private data: Uint8Array;
  private view: DataView;
  private numTags: number;
  private referenceStart: number;
  private secondaryStart: number;
  private formatVersion: number;

  /**
   * Build a new local autocompleter.
   */
  constructor(backingStore: ArrayBuffer) {
    this.encoder = new TextEncoder();
    this.decoder = new TextDecoder();
    this.data = new Uint8Array(backingStore);
    this.view = new DataView(backingStore);
    this.numTags = this.view.getUint32(backingStore.byteLength - 4, true);
    this.referenceStart = this.view.getUint32(backingStore.byteLength - 8, true);
    this.secondaryStart = this.referenceStart + 8 * this.numTags;
    this.formatVersion = this.view.getUint32(backingStore.byteLength - 12, true);

    if (this.formatVersion !== 2) {
      throw new Error('Incompatible autocomplete format version');
    }
  }

  /**
   * Return the pointer to tag data for the given reference index.
   */
  private resolveTagReference(i: TagReferenceIndex, resolveAlias: boolean = true): TagPointer {
    const tagPointer = this.view.getUint32(this.referenceStart + i * 8, true);
    const imageCount = this.view.getInt32(this.referenceStart + i * 8 + 4, true);

    if (resolveAlias && imageCount < 0) {
      // This is actually an alias, so follow it
      return this.resolveTagReference(-imageCount - 1);
    }

    return tagPointer;
  }

  /**
   * Return whether the tag pointed to by the reference index is an alias.
   */
  private tagReferenceIsAlias(i: TagReferenceIndex): boolean {
    return this.view.getInt32(this.referenceStart + i * 8 + 4, true) < 0;
  }

  /**
   * Get the images count for the given reference index.
   */
  private getImageCount(i: TagReferenceIndex): number {
    const imageCount = this.view.getInt32(this.referenceStart + i * 8 + 4, true);

    if (imageCount < 0) {
      // This is actually an alias, so follow it
      return this.getImageCount(-imageCount - 1);
    }

    return imageCount;
  }

  /**
   * Return the name buffer of the pointed-to result.
   */
  private referenceToName(i: TagReferenceIndex, resolveAlias: boolean = true): Uint8Array {
    const pointer = this.resolveTagReference(i, resolveAlias);
    const nameLength = this.view.getUint8(pointer);
    return this.data.slice(pointer + 1, pointer + nameLength + 1);
  }

  /**
   * Return whether any associations in the pointed-to result are in comparisonValues.
   */
  private isFilteredByReference(comparisonValues: Set<number>, i: TagReferenceIndex): boolean {
    const pointer = this.resolveTagReference(i);
    const nameLength = this.view.getUint8(pointer);
    const assnLength = this.view.getUint8(pointer + 1 + nameLength);

    for (let j = 0; j < assnLength; j++) {
      const assnValue = this.view.getUint32(pointer + 1 + nameLength + 1 + j * 4, true);

      if (comparisonValues.has(assnValue)) {
        return true;
      }
    }

    return false;
  }

  /**
   * Return whether Result a is considered less than Result b.
   */
  private compareReferenceToReference(a: TagReferenceIndex, b: TagReferenceIndex): number {
    const imagesA = this.getImageCount(a);
    const imagesB = this.getImageCount(b);

    if (imagesA !== imagesB) {
      return imagesA - imagesB;
    }

    const nameA = this.referenceToName(a);
    const nameB = this.referenceToName(a);

    return strcmp(nameA, nameB);
  }

  /**
   * Get a Result object as the ith tag inside the file, secondary ordering.
   */
  private getSecondaryResultAt(i: number): TagReferenceIndex {
    return this.view.getUint32(this.secondaryStart + i * 4, true);
  }

  /**
   * Perform a binary search to fetch all results matching a condition.
   */
  private scanResults(
    getResult: (i: number) => TagReferenceIndex,
    compare: (result: TagReferenceIndex) => number,
    hasFilteredAssociation: (result: TagReferenceIndex) => boolean,
    isAlias: (result: TagReferenceIndex) => boolean,
    results: UniqueHeap<TagReferenceIndex>,
  ) {
    const filter = !store.get('unfilter_tag_suggestions');

    let min = 0;
    let max = this.numTags;

    while (min < max - 1) {
      const med = min + (((max - min) / 2) | 0);
      const referenceIndex = getResult(med);

      if (compare(referenceIndex) >= 0) {
        // too large, go left
        max = med;
      } else {
        // too small, go right
        min = med;
      }
    }

    // Scan forward until no more matches occur
    while (min < this.numTags - 1) {
      const referenceIndex = getResult(++min);

      if (compare(referenceIndex) !== 0) {
        break;
      }

      // Check if any associations are filtered
      if (filter && hasFilteredAssociation(referenceIndex)) {
        continue;
      }

      // Nothing was filtered, so add
      results.append(referenceIndex, !isAlias(referenceIndex));
    }
  }

  /**
   * Find the top K results by image count which match the given string prefix.
   */
  matchPrefix(prefixStr: string, k: number): Result[] {
    if (prefixStr.length === 0) {
      return [];
    }

    // Set up binary matching context
    const prefix = this.encoder.encode(prefixStr);
    const results = new UniqueHeap<TagReferenceIndex>(
      this.compareReferenceToReference.bind(this),
      this.resolveTagReference.bind(this),
      new Uint32Array(this.numTags),
    );

    // Set up filter context
    const hiddenTags = new Set(window.booru.hiddenTagList);
    const hasFilteredAssociation = this.isFilteredByReference.bind(this, hiddenTags);
    const isAlias = this.tagReferenceIsAlias.bind(this);

    // Find tags ordered by full name
    const prefixMatch = (i: TagReferenceIndex) =>
      strcmp(this.referenceToName(i, false).slice(0, prefix.length), prefix);
    const referenceToNameIndex = (i: number) => i;
    this.scanResults(referenceToNameIndex, prefixMatch, hasFilteredAssociation, isAlias, results);

    // Find tags ordered by name in namespace
    const namespaceMatch = (i: TagReferenceIndex) =>
      strcmp(nameInNamespace(this.referenceToName(i, false)).slice(0, prefix.length), prefix);
    const referenceToAliasIndex = this.getSecondaryResultAt.bind(this);
    this.scanResults(referenceToAliasIndex, namespaceMatch, hasFilteredAssociation, isAlias, results);

    // Convert top K from heap into result array
    return results.topK(k).map((i: TagReferenceIndex) => {
      const alias = this.decoder.decode(this.referenceToName(i, false));
      const canonical = this.decoder.decode(this.referenceToName(i));
      const result: Result = {
        canonical,
        images: this.getImageCount(i),
      };

      if (alias !== canonical) {
        result.alias = alias;
      }

      return result;
    });
  }
}
