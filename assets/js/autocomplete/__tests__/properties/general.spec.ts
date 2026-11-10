import { autocompleteTest } from '../context.ts';

autocompleteTest('should only work on known query fields', async ({ ctx, expect }) => {
  // First, testing just an empty name: this should not give any properties.
  await ctx.setInput('b');
  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "b<>",
      "suggestions": [],
    }
  `);

  // Next trying to match something for unknown name: this should not to give anything as well.
  await ctx.setName('unknown');
  await ctx.setInput('b');
  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "b<>",
      "suggestions": [],
    }
  `);

  // And now using valid query field.
  await ctx.setName('q');
  await ctx.setInput('d');
  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "d<>",
      "suggestions": [
        "(property) description",
        "(property) downvotes",
        "(property) duplicate_id",
        "(property) duration",
      ],
    }
  `);

  // When property name is valid, but does not exist in our maps, then do not match anything.
  await ctx.setInput('nonexistentproperty');
  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "nonexistentproperty<>",
      "suggestions": [],
    }
  `);

  // All properties are expected to be without whitespaces. This query specifically would fail to match by the RegExp.
  await ctx.setInput('deleted by user');
  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "deleted by user<>",
      "suggestions": [],
    }
  `);
});
