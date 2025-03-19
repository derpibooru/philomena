import { init } from '../context';

it('ignores the autocompletion results if Escape was pressed', async () => {
  const ctx = await init();

  // First request for the local autocomplete index was done
  expect(fetch).toHaveBeenCalledTimes(1);

  await Promise.all([ctx.setInput('mar'), ctx.keyDown('Escape')]);

  // The input must be empty because the user typed `mar` and pressed `Escape` right after that
  ctx.expectUi().toMatchInlineSnapshot(`
    {
      "input": "mar<>",
      "suggestions": [],
    }
  `);

  // No new requests must've been sent because the input was debounced early
  expect(fetch).toHaveBeenCalledTimes(1);

  await ctx.setInput('mar');

  ctx.expectUi().toMatchInlineSnapshot(`
    {
      "input": "mar<>",
      "suggestions": [
        "marvelous → beautiful  30",
        "mare  20",
        "market  10",
      ],
    }
  `);

  // Second request for the server-side suggestions.
  expect(fetch).toHaveBeenCalledTimes(2);

  ctx.setInput('mare');

  // After 300 milliseconds the debounce threshold is over, and the server-side
  // completions request is issued.
  vi.advanceTimersByTime(300);

  await ctx.keyDown('Escape');

  expect(fetch).toHaveBeenCalledTimes(3);

  ctx.expectUi().toMatchInlineSnapshot(`
    {
      "input": "mare<>",
      "suggestions": [],
    }
  `);

  ctx.setInput('mare');

  // Make sure that the user gets the results immediately without any debouncing (0 ms)
  await vi.advanceTimersByTimeAsync(0);

  ctx.expectUi().toMatchInlineSnapshot(`
    {
      "input": "mare<>",
      "suggestions": [
        "mare  20",
      ],
    }
  `);

  // The results must come from the cache, so no new fetch calls must have been made
  expect(fetch).toHaveBeenCalledTimes(3);
});
