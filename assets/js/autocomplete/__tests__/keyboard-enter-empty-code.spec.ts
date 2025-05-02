import { autocompleteTest } from './context';

autocompleteTest('should handle Enter key presses with empty code property', async ({ ctx, expect }) => {
  await ctx.setInput('f');

  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "f<>",
      "suggestions": [
        "forest  3",
        "force field  1",
        "fog  1",
        "flower  1",
      ],
    }
  `);

  await ctx.keyDown('ArrowDown');
  await ctx.keyDown('', { key: 'Enter' });

  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "forest<>",
      "suggestions": [],
    }
  `);
});
