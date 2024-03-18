import { defaultMatcher } from '../matcher';
import { termSpaceToImageField } from '../fields';
import { generateLexArray } from '../lex';
import { getAstMatcherForTerm } from '../term';
import { parseTokens } from '../parse';

function parseWithDefaultMatcher(term: string, fuzz: number) {
  return getAstMatcherForTerm(term, fuzz, defaultMatcher);
}

describe('Semantic analysis', () => {
  let documents: HTMLElement[];

  beforeAll(() => {
    const e0 = document.createElement('div');
    e0.setAttribute(termSpaceToImageField.id, '0');
    e0.setAttribute(termSpaceToImageField.tags, 'safe, solo, fluttershy');

    const e1 = document.createElement('div');
    e1.setAttribute(termSpaceToImageField.id, '1');
    e1.setAttribute(termSpaceToImageField.tags, 'suggestive, solo, fluttershy');

    const e2 = document.createElement('div');
    e2.setAttribute(termSpaceToImageField.id, '2');
    e2.setAttribute(termSpaceToImageField.tags, 'suggestive, fluttershy, twilight sparkle');

    documents = [e0, e1, e2];
  });

  it('should match single term expressions', () => {
    const tokens = generateLexArray('fluttershy', parseWithDefaultMatcher);
    const matcher = parseTokens(tokens);

    expect(matcher(documents[0])).toBe(true);
    expect(matcher(documents[1])).toBe(true);
    expect(matcher(documents[2])).toBe(true);
  });

  it('should match AND expressions', () => {
    const tokens = generateLexArray('fluttershy,solo', parseWithDefaultMatcher);
    const matcher = parseTokens(tokens);

    expect(matcher(documents[0])).toBe(true);
    expect(matcher(documents[1])).toBe(true);
    expect(matcher(documents[2])).toBe(false);
  });

  it('should match OR expressions', () => {
    const tokens = generateLexArray('suggestive || twilight sparkle', parseWithDefaultMatcher);
    const matcher = parseTokens(tokens);

    expect(matcher(documents[0])).toBe(false);
    expect(matcher(documents[1])).toBe(true);
    expect(matcher(documents[2])).toBe(true);
  });

  it('should match NOT expressions', () => {
    const tokens = generateLexArray('NOT twilight sparkle', parseWithDefaultMatcher);
    const matcher = parseTokens(tokens);

    expect(matcher(documents[0])).toBe(true);
    expect(matcher(documents[1])).toBe(true);
    expect(matcher(documents[2])).toBe(false);
  });

  it('should allow empty expressions', () => {
    const tokens = generateLexArray('', parseWithDefaultMatcher);
    const matcher = parseTokens(tokens);

    expect(matcher(documents[0])).toBe(false);
    expect(matcher(documents[1])).toBe(false);
    expect(matcher(documents[2])).toBe(false);
  });

  it('should throw on unpaired AND', () => {
    const tokens = generateLexArray(' AND ', parseWithDefaultMatcher);
    expect(() => parseTokens(tokens)).toThrow('Missing operand.');
  });

  it('should throw on unjoined parenthetical', () => {
    const tokens = generateLexArray('(safe) solo', parseWithDefaultMatcher);
    expect(() => parseTokens(tokens)).toThrow('Missing operator.');
  });
});
