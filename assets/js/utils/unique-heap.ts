export type Compare<T> = (a: T, b: T) => number;
export type Unique<T> = (a: T) => unknown;
export interface Collection<T> {
  [index: number]: T;
  length: number;
}

export class UniqueHeap<T> {
  private keys: Map<unknown, number>;
  private values: Collection<T>;
  private length: number;
  private compare: Compare<T>;
  private unique: Unique<T>;

  constructor(compare: Compare<T>, unique: Unique<T>, values: Collection<T>) {
    this.keys = new Map();
    this.values = values;
    this.length = 0;
    this.compare = compare;
    this.unique = unique;
  }

  append(value: T, forceReplace = false) {
    const key = this.unique(value);
    const prevIndex = this.keys.get(key);

    if (prevIndex === undefined) {
      this.keys.set(key, this.length);
      this.values[this.length++] = value;
    } else if (forceReplace) {
      this.values[prevIndex] = value;
    }
  }

  topK(k: number): T[] {
    // Create the output array.
    const output: T[] = [];

    for (const result of this.results()) {
      if (output.length >= k) {
        break;
      }

      output.push(result);
    }

    return output;
  }

  *results(): Generator<T, void, void> {
    const { values, length } = this;

    // Build the heap.
    for (let i = (length >> 1) - 1; i >= 0; i--) {
      this.heapify(length, i);
    }

    // Begin extracting values.
    for (let i = 0; i < length; i++) {
      // Top value is the largest.
      yield values[0];

      // Swap with the element at the end.
      const lastIndex = length - i - 1;
      values[0] = values[lastIndex];

      // Restore top value being the largest.
      this.heapify(lastIndex, 0);
    }
  }

  private heapify(length: number, initialIndex: number) {
    const { compare, values } = this;
    let i = initialIndex;

    while (true) {
      const left = 2 * i + 1;
      const right = 2 * i + 2;
      let largest = i;

      if (left < length && compare(values[largest], values[left]) < 0) {
        // Left child is in-bounds and larger than parent. Swap with left.
        largest = left;
      }

      if (right < length && compare(values[largest], values[right]) < 0) {
        // Right child is in-bounds and larger than parent or left. Swap with right.
        largest = right;
      }

      if (largest === i) {
        // Largest value was already the parent. Done.
        return;
      }

      // Swap.
      const temp = values[i];
      values[i] = values[largest];
      values[largest] = temp;

      // Repair the subtree previously containing the largest element.
      i = largest;
    }
  }
}
