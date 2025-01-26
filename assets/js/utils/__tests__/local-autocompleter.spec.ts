import { LocalAutocompleter } from '../local-autocompleter';
import { promises } from 'fs';
import { join } from 'path';
import { TextDecoder } from 'util';

describe('Local Autocompleter', () => {
  let mockData: ArrayBuffer;
  const defaultK = 5;

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

  describe('topK', () => {
    const termStem = ['f', 'o'].join('');

    let localAc: LocalAutocompleter;

    beforeAll(() => {
      localAc = new LocalAutocompleter(mockData);
    });

    beforeEach(() => {
      window.booru.hiddenTagList = [];
    });

    it('should return suggestions for exact tag name match', () => {
      const result = localAc.matchPrefix('safe', defaultK);
      expect(result).toEqual([expect.objectContaining({ aliasName: 'safe', name: 'safe', imageCount: 6 })]);
    });

    it('should return suggestion for original tag when passed an alias', () => {
      const result = localAc.matchPrefix('flowers', defaultK);
      expect(result).toEqual([expect.objectContaining({ aliasName: 'flowers', name: 'flower', imageCount: 1 })]);
    });

    it('should return suggestions sorted by image count', () => {
      const result = localAc.matchPrefix(termStem, defaultK);
      expect(result).toEqual([
        expect.objectContaining({ aliasName: 'forest', name: 'forest', imageCount: 3 }),
        expect.objectContaining({ aliasName: 'fog', name: 'fog', imageCount: 1 }),
        expect.objectContaining({ aliasName: 'force field', name: 'force field', imageCount: 1 }),
      ]);
    });

    it('should return namespaced suggestions without including namespace', () => {
      const result = localAc.matchPrefix('test', defaultK);
      expect(result).toEqual([
        expect.objectContaining({ aliasName: 'artist:test', name: 'artist:test', imageCount: 1 }),
      ]);
    });

    it('should return only the required number of suggestions', () => {
      const result = localAc.matchPrefix(termStem, 1);
      expect(result).toEqual([expect.objectContaining({ aliasName: 'forest', name: 'forest', imageCount: 3 })]);
    });

    it('should NOT return suggestions associated with hidden tags', () => {
      window.booru.hiddenTagList = [1];
      const result = localAc.matchPrefix(termStem, defaultK);
      expect(result).toEqual([]);
    });

    it('should return empty array for empty prefix', () => {
      const result = localAc.matchPrefix('', defaultK);
      expect(result).toEqual([]);
    });
  });
});
