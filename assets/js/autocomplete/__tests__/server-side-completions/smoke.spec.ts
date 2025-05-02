import { autocompleteTest } from '../context';

autocompleteTest('requests server-side autocomplete if local one has no results', async ({ ctx, expect }) => {
  await ctx.setInput('mar');

  // 1. Request the local autocomplete index.
  // 2. Request the server-side suggestions.
  expect(fetch).toHaveBeenCalledTimes(2);

  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "mar<>",
      "suggestions": [
        "marvelous → beautiful  30",
        "mare  20",
        "market  10",
      ],
    }
  `);

  await ctx.setInput('');

  // Make sure the response caching is insensitive to term case and leading whitespace.
  await ctx.setInput('mar');
  await ctx.setInput(' mar');
  await ctx.setInput(' Mar');
  await ctx.setInput('  MAR');

  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "  MAR<>",
      "suggestions": [
        "marvelous → beautiful  30",
        "mare  20",
        "market  10",
      ],
    }
  `);

  expect(fetch).toHaveBeenCalledTimes(2);

  // Trailing whitespace is still significant because terms may have internal spaces.
  await ctx.setInput('mar ');

  expect(fetch).toHaveBeenCalledTimes(3);
});
