import { UniqueHeap } from '../unique-heap';

describe('Unique Heap', () => {
  interface Result {
    name: string;
  }

  function compare(a: Result, b: Result): number {
    return a.name < b.name ? -1 : Number(a.name > b.name);
  }

  function unique(r: Result): string {
    return r.name;
  }

  test('it should return no results when empty', () => {
    const heap = new UniqueHeap<Result>(compare, unique, []);
    expect(heap.topK(5)).toEqual([]);
  });

  test("doesn't insert duplicate results", () => {
    const heap = new UniqueHeap<Result>(compare, unique, []);

    heap.append({ name: 'name' });
    heap.append({ name: 'name' });

    expect(heap.topK(2)).toEqual([expect.objectContaining({ name: 'name' })]);
  });

  test('it should return results in reverse sorted order', () => {
    const heap = new UniqueHeap<Result>(compare, unique, []);

    const names = [
      'alpha',
      'beta',
      'gamma',
      'delta',
      'epsilon',
      'zeta',
      'eta',
      'theta',
      'iota',
      'kappa',
      'lambda',
      'mu',
      'nu',
      'xi',
      'omicron',
      'pi',
      'rho',
      'sigma',
      'tau',
      'upsilon',
      'phi',
      'chi',
      'psi',
      'omega',
    ];

    for (const name of names) {
      heap.append({ name });
    }

    const results = heap.topK(5);

    expect(results).toEqual([
      expect.objectContaining({ name: 'zeta' }),
      expect.objectContaining({ name: 'xi' }),
      expect.objectContaining({ name: 'upsilon' }),
      expect.objectContaining({ name: 'theta' }),
      expect.objectContaining({ name: 'tau' }),
    ]);
  });
});
