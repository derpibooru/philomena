import { autocompleteTest } from './context';

autocompleteTest('supports navigation via keyboard', async ({ ctx, expect }) => {
  await ctx.setInput('f');

  await ctx.keyDown('ArrowDown');

  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "forest<>",
      "suggestions": [
        "👉 forest  3",
        "force field  1",
        "fog  1",
        "flower  1",
      ],
    }
  `);

  await ctx.keyDown('ArrowDown');

  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "force field<>",
      "suggestions": [
        "forest  3",
        "👉 force field  1",
        "fog  1",
        "flower  1",
      ],
    }
  `);

  await ctx.keyDown('ArrowDown', { ctrlKey: true });

  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "flower<>",
      "suggestions": [
        "forest  3",
        "force field  1",
        "fog  1",
        "👉 flower  1",
      ],
    }
  `);

  await ctx.keyDown('ArrowUp', { ctrlKey: true });

  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "forest<>",
      "suggestions": [
        "👉 forest  3",
        "force field  1",
        "fog  1",
        "flower  1",
      ],
    }
  `);

  await ctx.keyDown('Enter');

  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "forest<>",
      "suggestions": [],
    }
  `);

  await ctx.setInput('forest, t<>, safe');

  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "forest, t<>, safe",
      "suggestions": [
        "artist:test  1",
      ],
    }
  `);

  await ctx.keyDown('ArrowDown');

  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "forest, artist:test<>, safe",
      "suggestions": [
        "👉 artist:test  1",
      ],
    }
  `);

  await ctx.keyDown('Escape');

  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "forest, artist:test<>, safe",
      "suggestions": [],
    }
  `);

  await ctx.setInput('forest, t<>, safe');
  await ctx.keyDown('ArrowDown');
  await ctx.keyDown('Enter');

  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "forest, artist:test<>, safe",
      "suggestions": [],
    }
  `);
});
