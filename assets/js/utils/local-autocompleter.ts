// Client-side tag completion.
import { UniqueHeap } from './unique-heap';
import store from './store';
import { prefixMatchParts, TagSuggestion } from './suggestions-model';

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

function identity<T>(value: T) {
  return value;
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
  private view: DataView;
  private numTags: number;
  private referenceStart: number;
  private secondaryStart: number;
  private hiddenTags: Set<number>;
  private tagReferenceHeapStorage: Uint32Array;

  /**
   * Build a new local autocompleter from the compiled autocomplete index.
   */
  constructor(buffer: ArrayBuffer) {
    this.view = new DataView(buffer);

    const formatVersion = this.view.getUint32(buffer.byteLength - 12, true);

    if (formatVersion !== 2) {
      throw new Error('Incompatible autocomplete format version');
    }

    this.encoder = new TextEncoder();
    this.decoder = new TextDecoder();

    this.numTags = this.view.getUint32(buffer.byteLength - 4, true);
    this.referenceStart = this.view.getUint32(buffer.byteLength - 8, true);
    this.secondaryStart = this.referenceStart + 8 * this.numTags;
    this.tagReferenceHeapStorage = new Uint32Array(this.numTags);

    this.hiddenTags = new Set(window.booru.hiddenTagList);
  }

  /**
   * Return the pointer to tag data for the given reference index.
   */
  private resolveTagReference(i: TagReferenceIndex, resolveAlias = true): TagPointer {
    const refPointer = this.referenceStart + i * 8;
    const tagPointer = this.view.getUint32(refPointer, true);
    const imageCount = this.view.getInt32(refPointer + 4, true);

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
  private referenceToName(i: TagReferenceIndex, resolveAlias = true): Uint8Array {
    const pointer = this.resolveTagReference(i, resolveAlias);
    const nameLength = this.view.getUint8(pointer);

    return new Uint8Array(this.view.buffer, pointer + 1, nameLength);
  }

  /**
   * Return `true` if any associated tags are hidden for this tag.
   */
  private isHiddenTag(i: TagReferenceIndex): boolean {
    const pointer = this.resolveTagReference(i);
    const nameLength = this.view.getUint8(pointer);
    const assnLength = this.view.getUint8(pointer + 1 + nameLength);

    for (let j = 0; j < assnLength; j++) {
      const assnValue = this.view.getUint32(pointer + 1 + nameLength + 1 + j * 4, true);

      if (this.hiddenTags.has(assnValue)) {
        return true;
      }
    }

    return false;
  }

  /**
   * Return a number with the result of the comparison.
   * `=0` - means both tags are equal
   * `>0` - means `a` is greater than `b`
   * `<0` - means `b` is greater than `a`
   */
  private compareReferenceToReference(a: TagReferenceIndex, b: TagReferenceIndex): number {
    const imagesA = this.getImageCount(a);
    const imagesB = this.getImageCount(b);

    if (imagesA !== imagesB) {
      return imagesA - imagesB;
    }

    const nameA = this.referenceToName(a, false);
    const nameB = this.referenceToName(b, false);

    return strcmp(nameA, nameB);
  }

  /**
   * Get a tag reference from the secondary index that is ordered by tag names
   * stripped from their namespace.
   */
  private getSecondaryReferenceAt(i: number): TagReferenceIndex {
    return this.view.getUint32(this.secondaryStart + i * 4, true);
  }

  /**
   * Perform a binary search with a subsequent forward scan to fetch all results
   * matching a `compare` condition.
   */
  private queryIndex({
    prefix,
    mapName,
    mapIndex,
    results,
  }: {
    prefix: Uint8Array;
    mapName(name: Uint8Array): Uint8Array;
    mapIndex(index: number): TagReferenceIndex;
    results: UniqueHeap<TagReferenceIndex>;
  }) {
    const filter = !store.get('unfilter_tag_suggestions');

    let min = 0;
    let max = this.numTags;

    const compare = (index: TagReferenceIndex) => {
      return strcmp(mapName(this.referenceToName(index, false)).slice(0, prefix.length), prefix);
    };

    while (min < max - 1) {
      const med = min + (((max - min) / 2) | 0);
      const referenceIndex = mapIndex(med);

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
      const referenceIndex = mapIndex(++min);

      if (compare(referenceIndex) !== 0) {
        break;
      }

      // Check if any associations are filtered
      if (filter && this.isHiddenTag(referenceIndex)) {
        continue;
      }

      // Nothing was filtered, so add
      results.append(referenceIndex, !this.tagReferenceIsAlias(referenceIndex));
    }
  }

  /**
   * Find the top K results by image count which match the given string prefix.
   */
  matchPrefix(prefixStr: string, k: number): TagSuggestion[] {
    if (prefixStr.length === 0) {
      return [];
    }

    // Set up binary matching context
    const prefix = this.encoder.encode(prefixStr);
    const results = new UniqueHeap<TagReferenceIndex>(
      this.compareReferenceToReference.bind(this),
      this.resolveTagReference.bind(this),

      // We don't need to clear the buffer after previous usages. The `UniqueHeap`
      // tracks the length of the used area internally.
      this.tagReferenceHeapStorage,
    );

    // Find tags ordered by their full name
    this.queryIndex({
      mapIndex: identity,
      mapName: identity,
      prefix,
      results,
    });

    // Find tags ordered by name in namespace
    this.queryIndex({
      mapIndex: this.getSecondaryReferenceAt.bind(this),
      mapName: nameInNamespace,
      prefix,
      results,
    });

    // Convert top K from heap into result array
    return results.topK(k).map((i: TagReferenceIndex) => {
      const alias = this.decoder.decode(this.referenceToName(i, false));
      const canonical = this.decoder.decode(this.referenceToName(i));
      const images = this.getImageCount(i);

      if (alias === canonical) {
        return {
          canonical: prefixMatchParts(canonical, prefixStr),
          images,
        };
      }

      return {
        alias: prefixMatchParts(alias, prefixStr),
        canonical,
        images,
      };
    });
  }
}
