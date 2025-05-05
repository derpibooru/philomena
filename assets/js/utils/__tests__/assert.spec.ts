import { assertNotNull, assertNotUndefined, assertType } from '../assert';

describe('Assertion utilities', () => {
  describe('assertNotNull', () => {
    it('should return non-null values', () => {
      expect(assertNotNull(1)).toEqual(1);
      expect(assertNotNull('anything')).toEqual('anything');
    });

    it('should throw when passed a null value', () => {
      expect(() => assertNotNull(null)).toThrow('Expected non-null value');
    });
  });

  describe('assertNotUndefined', () => {
    it('should return non-undefined values', () => {
      expect(assertNotUndefined(1)).toEqual(1);
      expect(assertNotUndefined('anything')).toEqual('anything');
    });

    it('should throw when passed an undefined value', () => {
      expect(() => assertNotUndefined(undefined)).toThrow('Expected non-undefined value');
    });
  });

  describe('assertType', () => {
    it('should return values of the generic type', () => {
      expect(assertType({}, Object)).toMatchInlineSnapshot(`{}`);
    });

    describe('it should throw when passed a value of the wrong type', () => {
      test('for primitives', () => {
        expect(() => assertType('anything', Number)).toThrowErrorMatchingInlineSnapshot(
          `[Error: Expected value of type Number]`,
        );
      });

      test('for objects', () => {
        expect(() => assertType(new Error(), Array)).toThrowErrorMatchingInlineSnapshot(
          `[Error: Expected value of type Array, but got Error]`,
        );
      });
    });
  });
});
