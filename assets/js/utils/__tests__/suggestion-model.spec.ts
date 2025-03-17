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

  it(`should ignore case when matching`, () => {
    expect(prefixMatchParts('FOObar', 'foo')).toMatchInlineSnapshot(`
      [
        {
          "matched": "FOO",
        },
        "bar",
      ]
    `);
  });

  it(`should skip empty parts`, () => {
    expect(prefixMatchParts('foo', 'foo')).toMatchInlineSnapshot(`
      [
        {
          "matched": "foo",
        },
      ]
    `);
    expect(prefixMatchParts('foo', 'bar')).toMatchInlineSnapshot(`
      [
        "foo",
      ]
    `);
  });
});
