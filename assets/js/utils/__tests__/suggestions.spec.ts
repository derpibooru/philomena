import { fetchMock } from '../../../test/fetch-mock.ts';
import {
  fetchLocalAutocomplete,
  fetchSuggestions,
  createLocalAutocompleteResultFormatter,
  purgeSuggestionsCache,
  SuggestionsPopup,
  TermSuggestion,
} from '../suggestions.ts';
import fs from 'fs';
import path from 'path';
import { LocalAutocompleter } from '../local-autocompleter.ts';
import { afterEach } from 'vitest';
import { fireEvent } from '@testing-library/dom';
import { getRandomIntBetween } from '../../../test/randomness.ts';

const mockedSuggestionsEndpoint = '/endpoint?term=';
const mockedSuggestionsResponse = [
  { label: 'artist:assasinmonkey (1)', value: 'artist:assasinmonkey' },
  { label: 'artist:hydrusbeta (1)', value: 'artist:hydrusbeta' },
  { label: 'artist:the sexy assistant (1)', value: 'artist:the sexy assistant' },
  { label: 'artist:devinian (1)', value: 'artist:devinian' },
  { label: 'artist:moe (1)', value: 'artist:moe' },
];

function mockBaseSuggestionsPopup(includeMockedSuggestions: boolean = false): [SuggestionsPopup, HTMLInputElement] {
  const input = document.createElement('input');
  const popup = new SuggestionsPopup();

  document.body.append(input);
  popup.showForField(input);

  if (includeMockedSuggestions) {
    popup.renderSuggestions(mockedSuggestionsResponse);
  }

  return [popup, input];
}

const selectedItemClassName = 'autocomplete__item--selected';

describe('Suggestions', () => {
  let mockedAutocompleteBuffer: ArrayBuffer;
  let popup: SuggestionsPopup | undefined;
  let input: HTMLInputElement | undefined;

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

  afterEach(() => {
    if (input) {
      input.remove();
      input = undefined;
    }

    if (popup) {
      popup.hide();
      popup = undefined;
    }
  });

  describe('SuggestionsPopup', () => {
    it('should create the popup container', () => {
      [popup, input] = mockBaseSuggestionsPopup();

      expect(document.querySelector('.autocomplete')).toBeInstanceOf(HTMLElement);
      expect(popup.isActive).toBe(true);
    });

    it('should be removed when hidden', () => {
      [popup, input] = mockBaseSuggestionsPopup();

      popup.hide();

      expect(document.querySelector('.autocomplete')).not.toBeInstanceOf(HTMLElement);
      expect(popup.isActive).toBe(false);
    });

    it('should render suggestions', () => {
      [popup, input] = mockBaseSuggestionsPopup(true);

      expect(document.querySelectorAll('.autocomplete__item').length).toBe(mockedSuggestionsResponse.length);
    });

    it('should initially select first element when selectNext called', () => {
      [popup, input] = mockBaseSuggestionsPopup(true);

      popup.selectNext();

      expect(document.querySelector('.autocomplete__item:first-child')).toHaveClass(selectedItemClassName);
    });

    it('should initially select last element when selectPrevious called', () => {
      [popup, input] = mockBaseSuggestionsPopup(true);

      popup.selectPrevious();

      expect(document.querySelector('.autocomplete__item:last-child')).toHaveClass(selectedItemClassName);
    });

    it('should select and de-select items when hovering items over', () => {
      [popup, input] = mockBaseSuggestionsPopup(true);

      const firstItem = document.querySelector('.autocomplete__item:first-child');
      const lastItem = document.querySelector('.autocomplete__item:last-child');

      if (firstItem) {
        fireEvent.mouseOver(firstItem);
        fireEvent.mouseMove(firstItem);
      }

      expect(firstItem).toHaveClass(selectedItemClassName);

      if (lastItem) {
        fireEvent.mouseOver(lastItem);
        fireEvent.mouseMove(lastItem);
      }

      expect(firstItem).not.toHaveClass(selectedItemClassName);
      expect(lastItem).toHaveClass(selectedItemClassName);

      if (lastItem) {
        fireEvent.mouseOut(lastItem);
      }

      expect(lastItem).not.toHaveClass(selectedItemClassName);
    });

    it('should allow switching between mouse and selection', () => {
      [popup, input] = mockBaseSuggestionsPopup(true);

      const secondItem = document.querySelector('.autocomplete__item:nth-child(2)');
      const thirdItem = document.querySelector('.autocomplete__item:nth-child(3)');

      if (secondItem) {
        fireEvent.mouseOver(secondItem);
        fireEvent.mouseMove(secondItem);
      }

      expect(secondItem).toHaveClass(selectedItemClassName);

      popup.selectNext();

      expect(secondItem).not.toHaveClass(selectedItemClassName);
      expect(thirdItem).toHaveClass(selectedItemClassName);
    });

    it('should loop around when selecting next on last and previous on first', () => {
      [popup, input] = mockBaseSuggestionsPopup(true);

      const firstItem = document.querySelector('.autocomplete__item:first-child');
      const lastItem = document.querySelector('.autocomplete__item:last-child');

      if (lastItem) {
        fireEvent.mouseOver(lastItem);
        fireEvent.mouseMove(lastItem);
      }

      expect(lastItem).toHaveClass(selectedItemClassName);

      popup.selectNext();

      expect(document.querySelector(`.${selectedItemClassName}`)).toBeNull();

      popup.selectNext();

      expect(firstItem).toHaveClass(selectedItemClassName);

      popup.selectPrevious();

      expect(document.querySelector(`.${selectedItemClassName}`)).toBeNull();

      popup.selectPrevious();

      expect(lastItem).toHaveClass(selectedItemClassName);
    });

    it('should return selected item value', () => {
      [popup, input] = mockBaseSuggestionsPopup(true);

      expect(popup.selectedTerm).toBe(null);

      popup.selectNext();

      expect(popup.selectedTerm).toBe(mockedSuggestionsResponse[0].value);
    });

    it('should emit an event when item was clicked with mouse', () => {
      [popup, input] = mockBaseSuggestionsPopup(true);

      let clickEvent: CustomEvent<TermSuggestion> | undefined;

      const itemSelectedHandler = vi.fn((event: CustomEvent<TermSuggestion>) => {
        clickEvent = event;
      });

      popup.onItemSelected(itemSelectedHandler);

      const firstItem = document.querySelector('.autocomplete__item');

      if (firstItem) {
        fireEvent.click(firstItem);
      }

      expect(itemSelectedHandler).toBeCalledTimes(1);
      expect(clickEvent?.detail).toEqual(mockedSuggestionsResponse[0]);
    });

    it('should not emit selection on items without value', () => {
      [popup, input] = mockBaseSuggestionsPopup();

      popup.renderSuggestions([{ label: 'Option without value', value: '' }]);

      const itemSelectionHandler = vi.fn();

      popup.onItemSelected(itemSelectionHandler);

      const firstItem = document.querySelector('.autocomplete__item:first-child')!;

      if (firstItem) {
        fireEvent.click(firstItem);
      }

      expect(itemSelectionHandler).not.toBeCalled();
    });
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
      fetchMock.mockResolvedValue(new Response(mockedAutocompleteBuffer, { status: 200 }));

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

  describe('createLocalAutocompleteResultFormatter', () => {
    it('should format suggested tags as tag name and the count', () => {
      const tagName = 'safe';
      const tagCount = getRandomIntBetween(5, 10);

      const formatter = createLocalAutocompleteResultFormatter();
      const resultObject = formatter({
        name: tagName,
        aliasName: tagName,
        imageCount: tagCount,
      });

      expect(resultObject.label).toBe(`${tagName} (${tagCount})`);
      expect(resultObject.value).toBe(tagName);
    });

    it('should display original alias name for aliased tags', () => {
      const tagName = 'safe';
      const tagAlias = 'rating:safe';
      const tagCount = getRandomIntBetween(5, 10);

      const formatter = createLocalAutocompleteResultFormatter();
      const resultObject = formatter({
        name: tagName,
        aliasName: tagAlias,
        imageCount: tagCount,
      });

      expect(resultObject.label).toBe(`${tagAlias} ⇒ ${tagName} (${tagCount})`);
      expect(resultObject.value).toBe(tagName);
    });

    it('should not display aliases when tag is starting with the same matched', () => {
      const tagName = 'chest fluff';
      const tagAlias = 'chest floof';
      const tagCount = getRandomIntBetween(5, 10);

      const prefix = 'ch';

      const formatter = createLocalAutocompleteResultFormatter(prefix);
      const resultObject = formatter({
        name: tagName,
        aliasName: tagAlias,
        imageCount: tagCount,
      });

      expect(resultObject.label).toBe(`${tagName} (${tagCount})`);
    });

    it('should display aliases if matched prefix is different from the tag name', () => {
      const tagName = 'queen chrysalis';
      const tagAlias = 'chrysalis';
      const tagCount = getRandomIntBetween(5, 10);

      const prefix = 'ch';

      const formatter = createLocalAutocompleteResultFormatter(prefix);
      const resultObject = formatter({
        name: tagName,
        aliasName: tagAlias,
        imageCount: tagCount,
      });

      expect(resultObject.label).toBe(`${tagAlias} ⇒ ${tagName} (${tagCount})`);
    });
  });
});
