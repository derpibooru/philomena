import { autocompleteTest } from '../context.ts';

autocompleteTest('should suggest values for some properties', async ({ ctx, expect }) => {
  await ctx.setName('q');

  // Checking the boolean type of property
  await ctx.setInput('animated:');
  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "animated:<>",
      "suggestions": [
        "(property) animated:true",
        "(property) animated:false",
      ],
    }
  `);

  // Special "my" namespace
  await ctx.setInput('my:');
  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "my:<>",
      "suggestions": [
        "(property) my:comments",
        "(property) my:faves",
        "(property) my:hidden",
        "(property) my:subs",
        "(property) my:uploads",
        "(property) my:upvotes",
        "(property) my:watched",
      ],
    }
  `);

  // Making sure values are matched by name
  await ctx.setInput('my:up');
  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "my:up<>",
      "suggestions": [
        "(property) my:uploads",
        "(property) my:upvotes",
      ],
    }
  `);

  // Checking if properties with tags as values suggesting them
  await ctx.setName('tq');
  await ctx.setInput('implies:f');
  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "implies:f<>",
      "suggestions": [
        "(property) implies:forest",
        "(property) implies:force field",
        "(property) implies:fog",
        "(property) implies:flower",
      ],
    }
  `);

  // Tag aliases should work as well
  await ctx.setInput('implies:flowers');
  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "implies:flowers<>",
      "suggestions": [
        "(property) implies:flower",
      ],
    }
  `);

  // And if tag isn't matched, then just display the value user specified
  await ctx.setInput('implies:something unexpected');
  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "implies:something unexpected<>",
      "suggestions": [
        "(property) implies:something unexpected",
      ],
    }
  `);

  // No values expected to appear on nonexistent properties
  await ctx.setInput('nonexistentproperty:');
  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "nonexistentproperty:<>",
      "suggestions": [],
    }
  `);
});
