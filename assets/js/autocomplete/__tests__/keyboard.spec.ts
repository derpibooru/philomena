import { init } from './context';

it('supports navigation via keyboard', async () => {
  const ctx = await init();

  await ctx.setInput('f');

  await ctx.keyDown('ArrowDown');

  ctx.expectUi().toMatchInlineSnapshot(`
    {
      "input": "forest<>",
      "suggestions": [
        "👉 forest  3",
        "fog  1",
        "force field  1",
        "flower  1",
      ],
    }
  `);

  await ctx.keyDown('ArrowDown');

  ctx.expectUi().toMatchInlineSnapshot(`
    {
      "input": "fog<>",
      "suggestions": [
        "forest  3",
        "👉 fog  1",
        "force field  1",
        "flower  1",
      ],
    }
  `);

  await ctx.keyDown('ArrowDown', { ctrlKey: true });

  ctx.expectUi().toMatchInlineSnapshot(`
    {
      "input": "flower<>",
      "suggestions": [
        "forest  3",
        "fog  1",
        "force field  1",
        "👉 flower  1",
      ],
    }
  `);

  await ctx.keyDown('ArrowUp', { ctrlKey: true });

  ctx.expectUi().toMatchInlineSnapshot(`
    {
      "input": "forest<>",
      "suggestions": [
        "👉 forest  3",
        "fog  1",
        "force field  1",
        "flower  1",
      ],
    }
  `);

  await ctx.keyDown('Enter');

  ctx.expectUi().toMatchInlineSnapshot(`
    {
      "input": "forest<>",
      "suggestions": [],
    }
  `);

  await ctx.setInput('forest, t<>, safe');

  ctx.expectUi().toMatchInlineSnapshot(`
    {
      "input": "forest, t<>, safe",
      "suggestions": [
        "artist:test  1",
      ],
    }
  `);

  await ctx.keyDown('ArrowDown');

  ctx.expectUi().toMatchInlineSnapshot(`
    {
      "input": "forest, artist:test<>, safe",
      "suggestions": [
        "👉 artist:test  1",
      ],
    }
  `);

  await ctx.keyDown('Escape');

  ctx.expectUi().toMatchInlineSnapshot(`
    {
      "input": "forest, artist:test<>, safe",
      "suggestions": [],
    }
  `);

  await ctx.setInput('forest, t<>, safe');
  await ctx.keyDown('ArrowDown');
  await ctx.keyDown('Enter');

  ctx.expectUi().toMatchInlineSnapshot(`
    {
      "input": "forest, artist:test<>, safe",
      "suggestions": [],
    }
  `);
});
