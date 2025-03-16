import { init } from './context';

it('records search history', async () => {
  const ctx = await init();

  await ctx.submitForm('foo1');

  // Empty input should show all latest history items
  ctx.expectUi().toMatchInlineSnapshot(`
    {
      "input": "",
      "suggestions": [
        "(history) foo1",
      ],
    }
  `);

  await ctx.submitForm('foo2');

  ctx.expectUi().toMatchInlineSnapshot(`
    {
      "input": "",
      "suggestions": [
        "(history) foo2",
        "(history) foo1",
      ],
    }
  `);

  await ctx.submitForm('a complex OR (query AND bar)');

  ctx.expectUi().toMatchInlineSnapshot(`
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

  ctx.expectUi().toMatchInlineSnapshot(`
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

  ctx.expectUi().toMatchInlineSnapshot(`
    {
      "input": "a com<>",
      "suggestions": [
        "(history) a complex OR (query AND bar)",
      ],
    }
  `);

  await ctx.setInput('f');

  ctx.expectUi().toMatchInlineSnapshot(`
    {
      "input": "f<>",
      "suggestions": [
        "(history) foo2",
        "(history) foo1",
        "-----------",
        "forest  3",
        "fog  1",
        "force field  1",
        "flower  1",
      ],
    }
  `);

  // History items must be selectable
  await ctx.keyDown('ArrowDown');

  ctx.expectUi().toMatchInlineSnapshot(`
    {
      "input": "foo2<>",
      "suggestions": [
        "👉 (history) foo2",
        "(history) foo1",
        "-----------",
        "forest  3",
        "fog  1",
        "force field  1",
        "flower  1",
      ],
    }
  `);
});
