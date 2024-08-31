import { fetchMock } from '../../../test/fetch-mock.ts';
import { fetchLocalAutocomplete, fetchSuggestions, purgeSuggestionsCache } from '../suggestions.ts';
import fs from 'fs';
import path from 'path';
import { LocalAutocompleter } from '../local-autocompleter.ts';

const mockedSuggestionsEndpoint = '/endpoint?term=';
const mockedSuggestionsResponse = [
  { label: 'artist:assasinmonkey (1)', value: 'artist:assasinmonkey' },
  { label: 'artist:hydrusbeta (1)', value: 'artist:hydrusbeta' },
  { label: 'artist:the sexy assistant (1)', value: 'artist:the sexy assistant' },
  { label: 'artist:devinian (1)', value: 'artist:devinian' },
  { label: 'artist:moe (1)', value: 'artist:moe' },
];

describe('Suggestions', () => {
  let mockedAutocompleteBuffer: ArrayBuffer;

  beforeAll(async () => {
    fetchMock.enableMocks();

    mockedAutocompleteBuffer = await fs.promises
      .readFile(path.join(__dirname, 'autocomplete-compiled-v2.bin'))
      .then(fileBuffer => fileBuffer.buffer);
  });

  afterAll(() => {
    fetchMock.disableMocks();
  });

  beforeEach(() => {
    purgeSuggestionsCache();
    fetchMock.resetMocks();
  });

  describe('fetchSuggestions', () => {
    it('should only call fetch once per single term', () => {
      fetchSuggestions(mockedSuggestionsEndpoint, 'art');
      fetchSuggestions(mockedSuggestionsEndpoint, 'art');

      expect(fetch).toHaveBeenCalledTimes(1);
    });

    it('should be case-insensitive to terms and trim spaces', () => {
      fetchSuggestions(mockedSuggestionsEndpoint, 'art');
      fetchSuggestions(mockedSuggestionsEndpoint, 'Art');
      fetchSuggestions(mockedSuggestionsEndpoint, '   ART   ');

      expect(fetch).toHaveBeenCalledTimes(1);
    });

    it('should return the same suggestions from cache', async () => {
      fetchMock.mockResolvedValueOnce(new Response(JSON.stringify(mockedSuggestionsResponse), { status: 200 }));

      const firstSuggestions = await fetchSuggestions(mockedSuggestionsEndpoint, 'art');
      const secondSuggestions = await fetchSuggestions(mockedSuggestionsEndpoint, 'art');

      expect(firstSuggestions).toBe(secondSuggestions);
    });

    it('should parse and return array of suggestions', async () => {
      fetchMock.mockResolvedValueOnce(new Response(JSON.stringify(mockedSuggestionsResponse), { status: 200 }));

      const resolvedSuggestions = await fetchSuggestions(mockedSuggestionsEndpoint, 'art');

      expect(resolvedSuggestions).toBeInstanceOf(Array);
      expect(resolvedSuggestions.length).toBe(mockedSuggestionsResponse.length);
      expect(resolvedSuggestions).toEqual(mockedSuggestionsResponse);
    });

    it('should return empty array on server error', async () => {
      fetchMock.mockResolvedValueOnce(new Response('', { status: 500 }));

      const resolvedSuggestions = await fetchSuggestions(mockedSuggestionsEndpoint, 'unknown tag');

      expect(resolvedSuggestions).toBeInstanceOf(Array);
      expect(resolvedSuggestions.length).toBe(0);
    });

    it('should return empty array on invalid response format', async () => {
      fetchMock.mockResolvedValueOnce(new Response('invalid non-JSON response', { status: 200 }));

      const resolvedSuggestions = await fetchSuggestions(mockedSuggestionsEndpoint, 'invalid response');

      expect(resolvedSuggestions).toBeInstanceOf(Array);
      expect(resolvedSuggestions.length).toBe(0);
    });
  });

  describe('purgeSuggestionsCache', () => {
    it('should clear cached responses', async () => {
      fetchMock.mockResolvedValueOnce(new Response(JSON.stringify(mockedSuggestionsResponse), { status: 200 }));

      const firstResult = await fetchSuggestions(mockedSuggestionsEndpoint, 'art');
      purgeSuggestionsCache();
      const resultAfterPurge = await fetchSuggestions(mockedSuggestionsEndpoint, 'art');

      expect(fetch).toBeCalledTimes(2);
      expect(firstResult).not.toBe(resultAfterPurge);
    });
  });

  describe('fetchLocalAutocomplete', () => {
    it('should request binary with date-related cache key', () => {
      const now = new Date();
      const cacheKey = `${now.getUTCFullYear()}-${now.getUTCMonth()}-${now.getUTCDate()}`;
      const expectedEndpoint = `/autocomplete/compiled?vsn=2&key=${cacheKey}`;

      fetchLocalAutocomplete();

      expect(fetch).toBeCalledWith(expectedEndpoint, { credentials: 'omit', cache: 'force-cache' });
    });

    it('should return auto-completer instance', async () => {
      fetchMock.mockResolvedValue(new Response(mockedAutocompleteBuffer, { status: 200 }));

      const autocomplete = await fetchLocalAutocomplete();

      expect(autocomplete).toBeInstanceOf(LocalAutocompleter);
    });

    it('should throw generic server error on failing response', async () => {
      fetchMock.mockResolvedValue(new Response('error', { status: 500 }));

      expect(() => fetchLocalAutocomplete()).rejects.toThrowError('Received error from server');
    });
  });
});
