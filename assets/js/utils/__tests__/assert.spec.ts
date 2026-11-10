import { assertNotNull, assertNotUndefined, assertString, assertType, assertNullableType } from '../assert';

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

  describe('assertString', () => {
    it('should return string values', () => {
      expect(assertString('anything')).toEqual('anything');
    });

    it('should throw when passed a non-string value', () => {
      expect(() => assertString(undefined)).toThrow('Expected string value');
      expect(() => assertString(null)).toThrow('Expected string value');
      expect(() => assertString(1)).toThrow('Expected string value');
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

  describe('assertNullableType', () => {
    it('should return values of the generic type', () => {
      expect(assertNullableType({}, Object)).toMatchInlineSnapshot(`{}`);
    });

    it('should return values of null', () => {
      expect(assertNullableType(null, Object)).toBeNull();
    });

    describe('it should throw when passed a value of the wrong type', () => {
      test('for primitives', () => {
        expect(() => assertNullableType('anything', Number)).toThrowErrorMatchingInlineSnapshot(
          `[Error: Expected value of type Number]`,
        );
      });

      test('for objects', () => {
        expect(() => assertNullableType(new Error(), Array)).toThrowErrorMatchingInlineSnapshot(
          `[Error: Expected value of type Array, but got Error]`,
        );
      });
    });
  });
});
