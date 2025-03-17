import { prefixMatchParts } from '../suggestions-model.ts';

describe('prefixMatchParts', () => {
  it('separates the prefix from the plain tag', () => {
    expect(prefixMatchParts('foobar', 'foo')).toMatchInlineSnapshot(`
      [
        {
          "matched": "foo",
        },
        "bar",
      ]
    `);
  });

  it('separates the prefix from the namespaced tag', () => {
    expect(prefixMatchParts('bruh:bar', 'bru')).toMatchInlineSnapshot(`
      [
        {
          "matched": "bru",
        },
        "h:bar",
      ]
    `);
  });

  it('separates the prefix after the namespace', () => {
    expect(prefixMatchParts('foo:bazz', 'baz')).toMatchInlineSnapshot(`
      [
        "foo:",
        {
          "matched": "baz",
        },
        "z",
      ]
    `);
  });
});
