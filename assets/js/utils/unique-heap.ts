export type Compare<T> = (a: T, b: T) => boolean;

export class UniqueHeap<T extends object> {
  private keys: Set<unknown>;
  private values: T[];
  private keyName: keyof T;
  private compare: Compare<T>;

  constructor(compare: Compare<T>, keyName: keyof T) {
    this.keys = new Set();
    this.values = [];
    this.keyName = keyName;
    this.compare = compare;
  }

  append(value: T) {
    const key = value[this.keyName];

    if (!this.keys.has(key)) {
      this.keys.add(key);
      this.values.push(value);
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
    const { values } = this;
    const length = values.length;

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

      if (left < length && compare(values[largest], values[left])) {
        // Left child is in-bounds and larger than parent. Swap with left.
        largest = left;
      }

      if (right < length && compare(values[largest], values[right])) {
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
