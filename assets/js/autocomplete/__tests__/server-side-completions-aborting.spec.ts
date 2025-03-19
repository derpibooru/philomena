import { init } from './context';

it('ignores the autocompletion results if Escape was pressed', async () => {
  const ctx = await init();

  await Promise.all([ctx.setInput('mar'), ctx.keyDown('Escape')]);

  // The input must be empty because the user typed `mar` and pressed `Escape` right after that
  ctx.expectUi().toMatchInlineSnapshot(`
    {
      "input": "mar<>",
      "suggestions": [],
    }
  `);

  // First request for the local autocomplete index.
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
});
