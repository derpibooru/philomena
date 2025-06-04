import { autocompleteTest } from './context';

autocompleteTest('records search history', async ({ ctx, expect }) => {
  await ctx.submitForm('foo1');

  // Empty input should show all latest history items
  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "",
      "suggestions": [
        "(history) foo1",
      ],
    }
  `);

  await ctx.submitForm('foo2');

  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "",
      "suggestions": [
        "(history) foo2",
        "(history) foo1",
      ],
    }
  `);

  await ctx.submitForm('a complex OR (query AND bar)');

  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "",
      "suggestions": [
        "(history) a complex OR (query AND bar)",
        "(history) foo2",
        "(history) foo1",
      ],
    }
  `);

  // Last recently used item should be on top
  await ctx.submitForm('foo2');

  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "",
      "suggestions": [
        "(history) foo2",
        "(history) a complex OR (query AND bar)",
        "(history) foo1",
      ],
    }
  `);

  await ctx.setInput('a com');

  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "a com<>",
      "suggestions": [
        "(history) a complex OR (query AND bar)",
      ],
    }
  `);

  await ctx.setInput('f');

  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "f<>",
      "suggestions": [
        "(history) foo2",
        "(history) foo1",
        "-----------",
        "forest  3",
        "force field  1",
        "fog  1",
        "flower  1",
      ],
    }
  `);

  // History items must be selectable
  await ctx.keyDown('ArrowDown');

  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "foo2<>",
      "suggestions": [
        "👉 (history) foo2",
        "(history) foo1",
        "-----------",
        "forest  3",
        "force field  1",
        "fog  1",
        "flower  1",
      ],
    }
  `);
});
