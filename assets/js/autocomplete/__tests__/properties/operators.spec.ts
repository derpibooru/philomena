import { autocompleteTest } from '../context.ts';

autocompleteTest('should display operators for properties supporting them', async ({ ctx, expect }) => {
  await ctx.setName('q');

  // Testing numeric property operators.
  await ctx.setInput('score.');
  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "score.<>",
      "suggestions": [
        "(property) score.gt:",
        "(property) score.gte:",
        "(property) score.lt:",
        "(property) score.lte:",
      ],
    }
  `);

  // Testing operators appearing even if value is already given.
  await ctx.setInput('score:10');
  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "score:10<>",
      "suggestions": [
        "(property) score:10",
        "(property) score.gt:10",
        "(property) score.gte:10",
        "(property) score.lt:10",
        "(property) score.lte:10",
      ],
    }
  `);

  // Date fields should also use operators similar to the numeric ones
  await ctx.setInput('first_seen_at.');
  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "first_seen_at.<>",
      "suggestions": [
        "(property) first_seen_at.gt:",
        "(property) first_seen_at.gte:",
        "(property) first_seen_at.lt:",
        "(property) first_seen_at.lte:",
      ],
    }
  `);

  await ctx.setInput('first_seen_at:3 days ago');
  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "first_seen_at:3 days ago<>",
      "suggestions": [
        "(property) first_seen_at:3 days ago",
        "(property) first_seen_at.gt:3 days ago",
        "(property) first_seen_at.gte:3 days ago",
        "(property) first_seen_at.lt:3 days ago",
        "(property) first_seen_at.lte:3 days ago",
      ],
    }
  `);

  // If property has operators but user haven't typed it yet, then show all available operators
  await ctx.setInput('first_seen_at:');
  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "first_seen_at:<>",
      "suggestions": [
        "(property) first_seen_at:",
        "(property) first_seen_at.gt:",
        "(property) first_seen_at.gte:",
        "(property) first_seen_at.lt:",
        "(property) first_seen_at.lte:",
      ],
    }
  `);

  // Making sure properties without operators are showing anything
  await ctx.setInput('my.');
  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "my.<>",
      "suggestions": [],
    }
  `);

  // Operators on nonexistent properties are just ignored
  await ctx.setInput('nonexistentproperty.');
  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "nonexistentproperty.<>",
      "suggestions": [],
    }
  `);
});
