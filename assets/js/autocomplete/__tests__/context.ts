import * as fs from 'fs';
import * as path from 'path';
import { fetchMock } from '../../../test/fetch-mock';
import { listenAutocomplete } from '..';
import { fireEvent } from '@testing-library/dom';
import { assertNotNull } from '../../utils/assert';
import { TextInputElement } from '../input';
import store from '../../utils/store';
import { GetTagSuggestionsResponse } from 'autocomplete/client';

/**
 * A reusable test environment for autocompletion tests. Note that it does no
 * attempt to provide environment cleanup functionality. Yes, if you use this
 * in several tests in one file, then tests will conflict with each other.
 *
 * The main problem of implementing the cleanup here is that autocomplete code
 * adds event listeners to the `document` object. Some of them could be moved
 * to the `<body>` element, but events such as `'storage'` are only available
 * on the document object.
 *
 * Unfortunately, there isn't a good easy way to reload the DOM completely in
 * `jsdom`, so it's expected that you define a single test per file so that
 * `vitest` runs every test in an isolated process, where no cleanup is needed.
 *
 * I wish `vitest` actually did that by default, because cleanup logic and test
 * in-process test isolation is just boilerplate that we could avoid at this
 * scale at least.
 */
export class TestContext {
  private input: TextInputElement;
  private popup: HTMLElement;
  readonly fakeAutocompleteResponse: Response;

  constructor(fakeAutocompleteResponse: Response) {
    this.fakeAutocompleteResponse = fakeAutocompleteResponse;

    vi.useFakeTimers().setSystemTime(0);
    fetchMock.enableMocks();

    // Our mock backend implementation.
    fetchMock.mockResponse(request => {
      if (request.url.includes('/autocomplete/compiled')) {
        return this.fakeAutocompleteResponse;
      }

      const url = new URL(request.url);
      if (url.searchParams.get('term')?.toLowerCase() !== 'mar') {
        const suggestions: GetTagSuggestionsResponse = { suggestions: [] };
        return JSON.stringify(suggestions);
      }

      const suggestions: GetTagSuggestionsResponse = {
        suggestions: [
          {
            alias: 'marvelous',
            canonical: 'beautiful',
            images: 30,
          },
          {
            canonical: 'mare',
            images: 20,
          },
          {
            canonical: 'market',
            images: 10,
          },
        ],
      };

      return JSON.stringify(suggestions);
    });

    store.set('enable_search_ac', true);

    document.body.innerHTML = `
      <form>
        <input
          class="test-input"
          data-autocomplete="multi-tags"
          data-autocomplete-condition="enable_search_ac"
          data-autocomplete-history-id="search-history"
        />
      </form>
    `;

    listenAutocomplete();

    this.input = assertNotNull(document.querySelector('.test-input'));
    this.popup = assertNotNull(document.querySelector('.autocomplete'));

    expect(fetch).not.toBeCalled();
  }

  async submitForm(input?: string) {
    if (input) {
      await this.setInput(input);
    }

    this.input.form!.submit();

    await this.setInput('');
  }

  async focusInput() {
    this.input.focus();
    await vi.runAllTimersAsync();
  }

  /**
   * Sets the input to `value`. Allows for a special `<>` syntax. These characters
   * are removed from the input. Their position is used to set the selection.
   *
   * - `<` denotes the `selectionStart`
   * - `>` denotes the `selectionEnd`.
   */
  async setInput(value: string) {
    if (document.activeElement !== this.input) {
      await this.focusInput();
    }

    const valueChars = [...value];

    const selectionStart = valueChars.indexOf('<');
    if (selectionStart >= 0) {
      valueChars.splice(selectionStart, 1);
    }

    const selectionEnd = valueChars.indexOf('>');
    if (selectionEnd >= 0) {
      valueChars.splice(selectionEnd, 1);
    }

    this.input.value = valueChars.join('');
    if (selectionStart >= 0) {
      this.input.selectionStart = selectionStart;
    }
    if (selectionEnd >= 0) {
      this.input.selectionEnd = selectionEnd;
    }

    fireEvent.input(this.input, { target: { value: this.input.value } });

    await vi.runAllTimersAsync();
  }

  async keyDown(code: string, params?: { ctrlKey?: boolean }) {
    fireEvent.keyDown(this.input, { code, ...(params ?? {}) });
    await vi.runAllTimersAsync();
  }

  expectRequests() {
    const snapshot = vi.mocked(fetch).mock.calls.map(([input]) => {
      const request = input as unknown as Request;
      const meta: Record<string, unknown> = {};

      const url = new URL(request.url);

      const methodAndUrl = `${request.method} ${url}`;

      if (request.credentials !== 'same-origin') {
        meta.credentials = request.credentials;
      }

      if (request.cache !== 'default') {
        meta.cache = request.cache;
      }

      if (Object.getOwnPropertyNames(meta).length === 0) {
        return methodAndUrl;
      }

      return {
        dest: methodAndUrl,
        meta,
      };
    });

    return expect(snapshot);
  }

  /**
   * The snapshot of the UI uses some special syntax like `<>` to denote the
   * selection start (`<`) and end (`>`), as well as some markers for the
   * currently selected item and history suggestions.
   */
  expectUi() {
    const input = this.inputSnapshot();
    const suggestions = this.suggestionsSnapshot();

    return expect({ input, suggestions });
  }

  suggestionsSnapshot() {
    const { popup } = this;

    if (popup.classList.contains('hidden')) {
      return [];
    }

    return [...popup.children].map(el => {
      if (el.tagName === 'HR') {
        return '-----------';
      }

      let content = el.textContent!.trim();

      if (el.classList.contains('autocomplete__item__history')) {
        content = `(history) ${content}`;
      }

      if (el.classList.contains('autocomplete__item--selected')) {
        return `👉 ${content}`;
      }
      return content;
    });
  }

  inputSnapshot() {
    const { input } = this;

    const value = [...input.value];

    if (input.selectionStart) {
      value.splice(input.selectionStart, 0, '<');
    }

    if (input.selectionEnd) {
      const shift = input.selectionStart && input.selectionStart <= input.selectionEnd ? 1 : 0;

      value.splice(input.selectionEnd + shift, 0, '>');
    }

    return value.join('');
  }
}

export async function init(): Promise<TestContext> {
  const fakeAutocompleteBuffer = await fs.promises
    .readFile(path.join(__dirname, '../../utils/__tests__/autocomplete-compiled-v2.bin'))
    .then(({ buffer }) => new Response(buffer));

  const ctx = new TestContext(fakeAutocompleteBuffer);

  expect(fetch).not.toHaveBeenCalled();

  // Initialize the lazy autocomplete index cache
  await ctx.focusInput();

  ctx.expectRequests().toMatchInlineSnapshot(`
    [
      {
        "dest": "GET http://localhost:3000/autocomplete/compiled?vsn=2&key=1970-0-1",
        "meta": {
          "cache": "force-cache",
          "credentials": "omit",
        },
      },
    ]
  `);

  ctx.expectUi().toMatchInlineSnapshot(`
    {
      "input": "",
      "suggestions": [],
    }
  `);

  return ctx;
}
