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
      expect(assertType({}, Object)).toEqual({});
    });

    it('should throw when passed a value of the wrong type', () => {
      expect(() => assertType('anything', Number)).toThrow('Expected value of type');
    });
  });
});
