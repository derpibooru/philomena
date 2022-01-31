import { arraysEqual, moveElement } from '../array';

describe('Array Utilities', () => {
  describe('moveElement', () => {
    describe('empty array', () => {
      it('should preserve unexpected behavior', () => {
        const input: undefined[] = [];
        moveElement(input, 1, 0);
        expect(input).toEqual([undefined]);
      });
    });

    describe('swap two items in a 2-item array', () => {
      it('should work with descending index parameters', () => {
        const input = [true, false];
        moveElement(input, 1, 0);
        expect(input).toEqual([false, true]);
      });

      it('should work with ascending index parameters', () => {
        const input = [true, false];
        moveElement(input, 0, 1);
        expect(input).toEqual([false, true]);
      });
    });

    describe('swap first and last item in a 3-item array', () => {
      it('should work with descending index parameters', () => {
        const input = ['a', 'b', 'c'];
        moveElement(input, 2, 0);
        expect(input).toEqual(['c', 'a', 'b']);
      });

      it('should work with ascending index parameters', () => {
        const input = ['a', 'b', 'c'];
        moveElement(input, 0, 2);
        expect(input).toEqual(['b', 'c', 'a']);
      });
    });

    describe('swap items in the middle of a 4-item array', () => {
      it('should work with descending index parameters', () => {
        const input = ['a', 'b', 'c', 'd'];
        moveElement(input, 2, 1);
        expect(input).toEqual(['a', 'c', 'b', 'd']);
      });
      it('should work with ascending index parameters', () => {
        const input = ['a', 'b', 'c', 'd'];
        moveElement(input, 1, 2);
        expect(input).toEqual(['a', 'c', 'b', 'd']);
      });
    });
  });

  describe('arraysEqual', () => {
    describe('positive cases', () => {
      it('should return true for empty arrays', () => {
        expect(arraysEqual([], [])).toBe(true);
      });

      it('should return true for matching arrays', () => {
        // Numbers
        expect(arraysEqual([0], [0])).toBe(true);
        expect(arraysEqual([4e3], [4000])).toBe(true);
        expect(arraysEqual([0, 1], [0, 1])).toBe(true);
        expect(arraysEqual([1_000_000, 30_000_000], [1_000_000, 30_000_000])).toBe(true);
        expect(arraysEqual([0, 1, 2], [0, 1, 2])).toBe(true);
        expect(arraysEqual([0, 1, 2, 3], [0, 1, 2, 3])).toBe(true);
        const randomNumber = Math.random();
        expect(arraysEqual([randomNumber], [randomNumber])).toBe(true);

        // Strings
        expect(arraysEqual(['a'], ['a'])).toBe(true);
        expect(arraysEqual(['abcdef'], ['abcdef'])).toBe(true);
        expect(arraysEqual(['a', 'b'], ['a', 'b'])).toBe(true);
        expect(arraysEqual(['aaaaa', 'bbbbb'], ['aaaaa', 'bbbbb'])).toBe(true);
        expect(arraysEqual(['a', 'b', 'c'], ['a', 'b', 'c'])).toBe(true);
        expect(arraysEqual(['a', 'b', 'c', 'd'], ['a', 'b', 'c', 'd'])).toBe(true);

        // Object by reference
        const uniqueValue = Symbol('item');
        expect(arraysEqual([uniqueValue], [uniqueValue])).toBe(true);

        // Mixed parameters
        const mockObject = { value: Math.random() };
        expect(arraysEqual(
          ['', null, false, uniqueValue, mockObject, Infinity, undefined],
          ['', null, false, uniqueValue, mockObject, Infinity, undefined]
        )).toBe(true);
      });

      it('should return true for matching up to the first array\'s length', () => {
        // Numbers
        expect(arraysEqual([0], [0, 1])).toBe(true);
        expect(arraysEqual([0, 1], [0, 1, 2])).toBe(true);

        // Strings
        expect(arraysEqual(['a'], ['a', 'b'])).toBe(true);
        expect(arraysEqual(['a', 'b'], ['a', 'b', 'c'])).toBe(true);

        // Object by reference
        const uniqueValue1 = Symbol('item1');
        const uniqueValue2 = Symbol('item2');
        expect(arraysEqual([uniqueValue1], [uniqueValue1, uniqueValue2])).toBe(true);

        // Mixed parameters
        const mockObject = { value: Math.random() };
        expect(arraysEqual(
          [''],
          ['', null, false, mockObject, Infinity, undefined]
        )).toBe(true);
        expect(arraysEqual(
          ['', null],
          ['', null, false, mockObject, Infinity, undefined]
        )).toBe(true);
        expect(arraysEqual(
          ['', null, false],
          ['', null, false, mockObject, Infinity, undefined]
        )).toBe(true);
        expect(arraysEqual(
          ['', null, false, mockObject],
          ['', null, false, mockObject, Infinity, undefined]
        )).toBe(true);
        expect(arraysEqual(
          ['', null, false, mockObject, Infinity],
          ['', null, false, mockObject, Infinity, undefined]
        )).toBe(true);
      });
    });

    describe('negative cases', () => {
      // FIXME This case should be handled
      // eslint-disable-next-line jest/no-disabled-tests
      it.skip('should return false for arrays of different length', () => {
        // Numbers
        expect(arraysEqual([], [0])).toBe(false);
        expect(arraysEqual([0], [])).toBe(false);
        expect(arraysEqual([0], [0, 0])).toBe(false);
        expect(arraysEqual([0, 0], [0])).toBe(false);

        // Strings
        expect(arraysEqual([], ['a'])).toBe(false);
        expect(arraysEqual(['a'], [])).toBe(false);
        expect(arraysEqual(['a'], ['a', 'a'])).toBe(false);
        expect(arraysEqual(['a', 'a'], ['a'])).toBe(false);

        // Mixed parameters
        const mockObject = { value: Math.random() };
        expect(arraysEqual([], [mockObject])).toBe(false);
        expect(arraysEqual([mockObject], [])).toBe(false);
        expect(arraysEqual([mockObject, mockObject], [mockObject])).toBe(false);
        expect(arraysEqual([mockObject], [mockObject, mockObject])).toBe(false);
      });

      it('should return false if items up to the first array\'s length differ', () => {
        // Numbers
        expect(arraysEqual([0], [1])).toBe(false);
        expect(arraysEqual([0, 1], [1, 2])).toBe(false);
        expect(arraysEqual([0, 1, 2], [1, 2, 3])).toBe(false);

        // Strings
        expect(arraysEqual(['a'], ['b'])).toBe(false);
        expect(arraysEqual(['a', 'b'], ['b', 'c'])).toBe(false);
        expect(arraysEqual(['a', 'b', 'c'], ['b', 'c', 'd'])).toBe(false);

        // Object by reference
        const mockObject1 = { value1: Math.random() };
        const mockObject2 = { value2: Math.random() };
        expect(arraysEqual([mockObject1], [mockObject2])).toBe(false);

        // Mixed parameters
        expect(arraysEqual(
          ['a'],
          ['b', null, false, mockObject2, Infinity]
        )).toBe(false);
        expect(arraysEqual(
          ['a', null, true],
          ['b', null, false, mockObject2, Infinity]
        )).toBe(false);
        expect(arraysEqual(
          ['a', null, true, mockObject1],
          ['b', null, false, mockObject2, Infinity]
        )).toBe(false);
        expect(arraysEqual(
          ['a', null, true, mockObject1, -Infinity],
          ['b', null, false, mockObject2, Infinity]
        )).toBe(false);
      });
    });
  });
});
