import { makeLiteralMatcher } from '../literal';

describe('Literal field parsing', () => {
  it('should handle exact matching in arrayed fields', () => {
    const matcher = makeLiteralMatcher('safe', 0, false);
    expect(matcher('safe, solo', 'tags', 0)).toBe(true);
    expect(matcher('solo', 'tags', 0)).toBe(false);
  });

  it('should handle exact matching in non-arrayed fields', () => {
    const matcher = makeLiteralMatcher('safe', 0, false);
    expect(matcher('safe, solo', 'description', 0)).toBe(false);
    expect(matcher('safe', 'description', 0)).toBe(true);
    expect(matcher('solo', 'description', 0)).toBe(false);
  });

  it('should handle fuzzy matching based on normalized edit distance', () => {
    const matcher = makeLiteralMatcher('fluttersho', 0.8, false);
    expect(matcher('fluttershy', 'tags', 0)).toBe(true);
    expect(matcher('rarity', 'tags', 0)).toBe(false);
  });

  it('should handle fuzzy matching based on raw edit distance', () => {
    const matcher = makeLiteralMatcher('fluttersho', 1, false);
    expect(matcher('fluttershy', 'tags', 0)).toBe(true);
    expect(matcher('rarity', 'tags', 0)).toBe(false);
  });

  it('should handle wildcard matching', () => {
    const matcher = makeLiteralMatcher('fl?tter*', 0, true);
    expect(matcher('fluttershy', 'tags', 0)).toBe(true);
    expect(matcher('flitter', 'tags', 0)).toBe(true);
    expect(matcher('rainbow dash', 'tags', 0)).toBe(false);
    expect(matcher('gentle flutter', 'tags', 0)).toBe(false);
  });
});
