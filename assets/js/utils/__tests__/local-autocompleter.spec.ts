import { LocalAutocompleter } from '../local-autocompleter';
import { promises } from 'fs';
import { join } from 'path';
import { TextDecoder } from 'util';

describe('LocalAutocompleter', () => {
  let mockData: ArrayBuffer;

  beforeAll(async () => {
    const mockDataPath = join(__dirname, 'autocomplete-compiled-v2.bin');
    /**
     * Read pre-generated binary autocomplete data
     *
     * Contains the tags: safe (6), forest (3), flower (1), flowers -> flower, fog (1),
     *                    force field (1), artist:test (1), explicit (0), grimdark (0),
     *                    grotesque (0), questionable (0), semi-grimdark (0), suggestive (0)
     */
    mockData = (await promises.readFile(mockDataPath, { encoding: null })).buffer;

    // Polyfills for jsdom
    global.TextDecoder = TextDecoder as unknown as typeof global.TextDecoder;
  });

  afterAll(() => {
    delete (global as Partial<typeof global>).TextEncoder;
    delete (global as Partial<typeof global>).TextDecoder;
  });

  describe('instantiation', () => {
    it('should be constructible with compatible data', () => {
      const result = new LocalAutocompleter(mockData);
      expect(result).toBeInstanceOf(LocalAutocompleter);
    });

    it('should NOT be constructible with incompatible data', () => {
      const versionDataOffset = 12;
      const mockIncompatibleDataArray = new Array(versionDataOffset).fill(0);
      // Set data version to 1
      mockIncompatibleDataArray[mockIncompatibleDataArray.length - versionDataOffset] = 1;
      const mockIncompatibleData = new Uint32Array(mockIncompatibleDataArray).buffer;

      expect(() => new LocalAutocompleter(mockIncompatibleData)).toThrow('Incompatible autocomplete format version');
    });
  });

  describe('matchPrefix', () => {
    const termStem = ['f', 'o'].join('');

    function expectLocalAutocomplete(term: string, topK = 5) {
      const localAutocomplete = new LocalAutocompleter(mockData);
      const results = localAutocomplete.matchPrefix(term, topK);
      const actual = results.map(result => {
        const canonical = `${result.canonical} (${result.images})`;
        return result.alias ? `${result.alias} -> ${canonical}` : canonical;
      });

      return expect(actual);
    }

    beforeEach(() => {
      window.booru.hiddenTagList = [];
    });

    it('should return suggestions for exact tag name match', () => {
      expectLocalAutocomplete('safe').toMatchInlineSnapshot(`
        [
          "safe (6)",
        ]
      `);
    });

    it('should return suggestion for an alias', () => {
      expectLocalAutocomplete('flowers').toMatchInlineSnapshot(`
        [
          "flowers -> flower (1)",
        ]
      `);
    });

    it('should prefer canonical tag over an alias when both match', () => {
      expectLocalAutocomplete('flo').toMatchInlineSnapshot(`
        [
          "flower (1)",
        ]
      `);
    });

    it('should return suggestions sorted by image count', () => {
      expectLocalAutocomplete(termStem).toMatchInlineSnapshot(`
        [
          "forest (3)",
          "fog (1)",
          "force field (1)",
        ]
      `);
    });

    it('should return namespaced suggestions without including namespace', () => {
      expectLocalAutocomplete('test').toMatchInlineSnapshot(`
        [
          "artist:test (1)",
        ]
      `);
    });

    it('should return only the required number of suggestions', () => {
      expectLocalAutocomplete(termStem, 1).toMatchInlineSnapshot(`
        [
          "forest (3)",
        ]
      `);
    });

    it('should NOT return suggestions associated with hidden tags', () => {
      window.booru.hiddenTagList = [1];
      expectLocalAutocomplete(termStem).toMatchInlineSnapshot(`[]`);
    });

    it('should return empty array for empty prefix', () => {
      expectLocalAutocomplete('').toMatchInlineSnapshot(`[]`);
    });
  });
});
