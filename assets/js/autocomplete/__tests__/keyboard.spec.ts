import { init, TestContext } from './context';

describe('Autocomplete keyboard navigation', () => {
  let ctx: TestContext;

  beforeAll(async () => {
    ctx = await init();
  });

  it('supports navigation via keyboard', async () => {
    await ctx.setInput('f');

    await ctx.keyDown('ArrowDown');

    ctx.expectUi().toMatchInlineSnapshot(`
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

    ctx.expectUi().toMatchInlineSnapshot(`
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

    ctx.expectUi().toMatchInlineSnapshot(`
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

    ctx.expectUi().toMatchInlineSnapshot(`
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

  it('should handle Enter key presses with empty code property', async () => {
    await ctx.setInput('f');

    ctx.expectUi().toMatchInlineSnapshot(`
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

    ctx.expectUi().toMatchInlineSnapshot(`
      {
        "input": "forest<>",
        "suggestions": [],
      }
    `);
  });
});
