import { autocompleteTest } from '../context.ts';

autocompleteTest('should support dotted property names', async ({ ctx, expect }) => {
  // Comment search properties contain nested fields with dots in their names.
  await ctx.setName('cq');

  // It should suggest properties with dots in names
  await ctx.setInput('image');
  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "image<>",
      "suggestions": [
        "(property) image_id",
        "(property) image.tags",
      ],
    }
  `);

  // Should understand and treat properties with dots in names as names
  await ctx.setInput('image.');
  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "image.<>",
      "suggestions": [
        "(property) image.tags",
      ],
    }
  `);

  // Suggest name past the dot
  await ctx.setInput('image.tag');
  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "image.tag<>",
      "suggestions": [
        "(property) image.tags",
      ],
    }
  `);

  // After the colon we can start suggesting the values
  await ctx.setInput('image.tags:');
  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "image.tags:<>",
      "suggestions": [
        "(property) image.tags:",
      ],
    }
  `);

  await ctx.setInput('image.tags:f');
  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "image.tags:f<>",
      "suggestions": [
        "(property) image.tags:forest",
        "(property) image.tags:force field",
        "(property) image.tags:fog",
        "(property) image.tags:flower",
      ],
    }
  `);

  // Tag aliases should work just fine.
  await ctx.setInput('image.tags:flowers');
  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "image.tags:flowers<>",
      "suggestions": [
        "(property) image.tags:flower",
      ],
    }
  `);

  // For now we don't have any numeric properties with dots in names, so no operators should be present
  await ctx.setInput('image.deleted.g');
  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "image.deleted.g<>",
      "suggestions": [],
    }
  `);

  // No rogue suggestions when no properties match
  await ctx.setInput('unknown.');
  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "unknown.<>",
      "suggestions": [],
    }
  `);

  // Operators for numeric/date fields should still work like before.
  await ctx.setInput('id.g');
  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "id.g<>",
      "suggestions": [
        "(property) id.gt:",
        "(property) id.gte:",
      ],
    }
  `);

  await ctx.setInput('id.gt:5');
  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "id.gt:5<>",
      "suggestions": [
        "(property) id.gt:5",
        "(property) id.gte:5",
      ],
    }
  `);
});
