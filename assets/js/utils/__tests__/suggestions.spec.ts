import {
  SuggestionsPopup,
  TagSuggestion,
  TagSuggestionParams,
  Suggestions,
  HistorySuggestion,
  ItemSelectedEvent,
} from '../suggestions.ts';
import { afterEach } from 'vitest';
import { fireEvent } from '@testing-library/dom';
import { assertNotNull } from '../assert.ts';

const mockedSuggestions: Suggestions = {
  history: ['foo bar', 'bar baz', 'baz qux'].map(content => new HistorySuggestion(content, 0)),
  tags: [
    { images: 10, canonical: 'artist:assasinmonkey' },
    { images: 10, canonical: 'artist:hydrusbeta' },
    { images: 10, canonical: 'artist:the sexy assistant' },
    { images: 10, canonical: 'artist:devinian' },
    { images: 10, canonical: 'artist:moe' },
  ].map(tags => new TagSuggestion({ ...tags, matchLength: 0 })),
};

function mockBaseSuggestionsPopup(includeMockedSuggestions: boolean = false): [SuggestionsPopup, HTMLInputElement] {
  const input = document.createElement('input');
  const popup = new SuggestionsPopup();

  document.body.append(input);
  popup.showForElement(input);

  if (includeMockedSuggestions) {
    popup.setSuggestions(mockedSuggestions);
  }

  return [popup, input];
}

const selectedItemClassName = 'autocomplete__item--selected';

describe('Suggestions', () => {
  let popup: SuggestionsPopup | undefined;
  let input: HTMLInputElement | undefined;

  afterEach(() => {
    if (input) {
      input.remove();
      input = undefined;
    }

    if (popup) {
      popup.hide();
      popup.setSuggestions({ history: [], tags: [] });
      popup = undefined;
    }
  });

  describe('SuggestionsPopup', () => {
    it('should create the popup container', () => {
      [popup, input] = mockBaseSuggestionsPopup();

      expect(document.querySelector('.autocomplete')).toBeInstanceOf(HTMLElement);
      expect(popup.isHidden).toBe(false);
    });

    it('should render suggestions', () => {
      [popup, input] = mockBaseSuggestionsPopup(true);

      expect(document.querySelectorAll('.autocomplete__item').length).toBe(
        mockedSuggestions.history.length + mockedSuggestions.tags.length,
      );
    });

    it('should initially select first element when selectDown is called', () => {
      [popup, input] = mockBaseSuggestionsPopup(true);

      popup.selectDown();

      expect(document.querySelector('.autocomplete__item:first-child')).toHaveClass(selectedItemClassName);
    });

    it('should initially select last element when selectUp is called', () => {
      [popup, input] = mockBaseSuggestionsPopup(true);

      popup.selectUp();

      expect(document.querySelector('.autocomplete__item:last-child')).toHaveClass(selectedItemClassName);
    });

    it('should jump to the next lower block when selectCtrlDown is called', () => {
      [popup, input] = mockBaseSuggestionsPopup(true);

      popup.selectCtrlDown();

      expect(popup.selectedSuggestion).toBe(mockedSuggestions.tags[0]);
      expect(document.querySelector('.autocomplete__item__tag')).toHaveClass(selectedItemClassName);

      popup.selectCtrlDown();

      expect(popup.selectedSuggestion).toBe(mockedSuggestions.tags.at(-1));
      expect(document.querySelector('.autocomplete__item__tag:last-child')).toHaveClass(selectedItemClassName);

      // Should loop around
      popup.selectCtrlDown();
      expect(popup.selectedSuggestion).toBe(mockedSuggestions.history[0]);
      expect(document.querySelector('.autocomplete__item:first-child')).toHaveClass(selectedItemClassName);
    });

    it('should jump to the next upper block when selectCtrlUp is called', () => {
      [popup, input] = mockBaseSuggestionsPopup(true);

      popup.selectCtrlUp();

      expect(popup.selectedSuggestion).toBe(mockedSuggestions.tags.at(-1));
      expect(document.querySelector('.autocomplete__item__tag:last-child')).toHaveClass(selectedItemClassName);

      popup.selectCtrlUp();

      expect(popup.selectedSuggestion).toBe(mockedSuggestions.history.at(-1));
      expect(
        document.querySelector(`.autocomplete__item__history:nth-child(${mockedSuggestions.history.length})`),
      ).toHaveClass(selectedItemClassName);

      popup.selectCtrlUp();

      expect(popup.selectedSuggestion).toBe(mockedSuggestions.history[0]);
      expect(document.querySelector('.autocomplete__item:first-child')).toHaveClass(selectedItemClassName);

      // Should loop around
      popup.selectCtrlUp();

      expect(popup.selectedSuggestion).toBe(mockedSuggestions.tags.at(-1));
      expect(document.querySelector('.autocomplete__item__tag:last-child')).toHaveClass(selectedItemClassName);
    });

    it('should do nothing on selection changes when empty', () => {
      [popup, input] = mockBaseSuggestionsPopup();

      popup.selectDown();
      popup.selectUp();
      popup.selectCtrlDown();
      popup.selectCtrlUp();

      expect(document.querySelector(`.${selectedItemClassName}`)).toBeNull();
    });

    it('should loop around when selecting next on last and previous on first', () => {
      [popup, input] = mockBaseSuggestionsPopup(true);

      const firstItem = assertNotNull(document.querySelector('.autocomplete__item:first-child'));
      const lastItem = assertNotNull(document.querySelector('.autocomplete__item:last-child'));

      popup.selectUp();

      expect(lastItem).toHaveClass(selectedItemClassName);

      popup.selectDown();

      expect(document.querySelector(`.${selectedItemClassName}`)).toBeNull();

      popup.selectDown();

      expect(firstItem).toHaveClass(selectedItemClassName);

      popup.selectUp();

      expect(document.querySelector(`.${selectedItemClassName}`)).toBeNull();

      popup.selectUp();

      expect(lastItem).toHaveClass(selectedItemClassName);
    });

    it('should return selected item value', () => {
      [popup, input] = mockBaseSuggestionsPopup(true);

      expect(popup.selectedSuggestion).toBe(null);

      popup.selectDown();

      expect(popup.selectedSuggestion).toBe(mockedSuggestions.history[0]);
    });

    it('should emit an event when an item was clicked with a mouse', () => {
      [popup, input] = mockBaseSuggestionsPopup(true);

      const itemSelectedHandler = vi.fn<(event: ItemSelectedEvent) => void>();

      popup.onItemSelected(itemSelectedHandler);

      const firstItem = assertNotNull(document.querySelector('.autocomplete__item'));

      fireEvent.click(firstItem);

      expect(itemSelectedHandler).toBeCalledTimes(1);
      expect(itemSelectedHandler).toBeCalledWith({
        ctrlKey: false,
        shiftKey: false,
        suggestion: mockedSuggestions.history[0],
      });
    });
  });

  describe('HistorySuggestion', () => {
    it('should render the suggestion', () => {
      expectHistoryRender('foo bar').toMatchInlineSnapshot(`
        {
          "label": " foo bar",
          "value": "foo bar",
        }
      `);
    });
  });

  describe('TagSuggestion', () => {
    it('should format suggested tags as tag name and the count', () => {
      expectTagRender({ canonical: 'safe', images: 10 }).toMatchInlineSnapshot(`
        {
          "label": " safe  10",
          "value": "safe",
        }
      `);
      expectTagRender({ canonical: 'safe', images: 10_000 }).toMatchInlineSnapshot(`
        {
          "label": " safe  10 000",
          "value": "safe",
        }
      `);
      expectTagRender({ canonical: 'safe', images: 100_000 }).toMatchInlineSnapshot(`
        {
          "label": " safe  100 000",
          "value": "safe",
        }
      `);
      expectTagRender({ canonical: 'safe', images: 1000_000 }).toMatchInlineSnapshot(`
        {
          "label": " safe  1 000 000",
          "value": "safe",
        }
      `);
      expectTagRender({ canonical: 'safe', images: 10_000_000 }).toMatchInlineSnapshot(`
        {
          "label": " safe  10 000 000",
          "value": "safe",
        }
      `);
    });

    it('should display alias -> canonical for aliased tags', () => {
      expectTagRender({ images: 10, canonical: 'safe', alias: 'rating:safe' }).toMatchInlineSnapshot(
        `
        {
          "label": " rating:safe → safe  10",
          "value": "safe",
        }
      `,
      );
    });
  });
});

function expectHistoryRender(content: string) {
  const suggestion = new HistorySuggestion(content, 0);
  const label = suggestion
    .render()
    .map(el => el.textContent)
    .join('');
  const value = suggestion.value();

  return expect({ label, value });
}

function expectTagRender(params: Omit<TagSuggestionParams, 'matchLength'>) {
  const suggestion = new TagSuggestion({ ...params, matchLength: 0 });
  const label = suggestion
    .render()
    .map(el => el.textContent)
    .join('');
  const value = suggestion.value();

  return expect({ label, value });
}
