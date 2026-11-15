import { autocompleteTest } from '../context.ts';

autocompleteTest('should show additional properties to staff', async ({ ctx, expect }) => {
  // Don't display staff properties by default
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

  // Admins, moderators and assistants should have extended list of properties suggested
  window.booru.userRole = 'admin';
  window.booru.hideStaffTools = false;
  await ctx.setInput('d');
  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "d<>",
      "suggestions": [
        "(property) deleted",
        "(property) deleted_by_user",
        "(property) deleted_by_user_id",
        "(property) deletion_reason",
        "(property) downvoted_by",
        "(property) downvoted_by_id",
        "(property) description",
        "(property) downvotes",
        "(property) duplicate_id",
        "(property) duration",
      ],
    }
  `);

  // But if admin has disabled the staff tools, then these properties should not appear
  window.booru.hideStaffTools = true;
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

  // Just making sure staff-only dotted properties are handled as well. Show only public by default.
  await ctx.setName('cq');
  await ctx.setInput('image.');
  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "image.<>",
      "suggestions": [
        "(property) image.tags",
      ],
    }
  `);

  // Once staff tools enabled, start showing the hidden properties.
  window.booru.hideStaffTools = false;
  await ctx.setInput('image.');
  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "image.<>",
      "suggestions": [
        "(property) image.approved",
        "(property) image.deleted",
        "(property) image.tags",
      ],
    }
  `);

  // And values...
  await ctx.setInput('image.deleted:');
  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "image.deleted:<>",
      "suggestions": [
        "(property) image.deleted:true",
        "(property) image.deleted:false",
      ],
    }
  `);

  await ctx.setInput('image.approved:t');
  expect(ctx.snapUi()).toMatchInlineSnapshot(`
    {
      "input": "image.approved:t<>",
      "suggestions": [
        "(property) image.approved:true",
      ],
    }
  `);
});
