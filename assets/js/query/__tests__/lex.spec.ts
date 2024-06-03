import { generateLexArray } from '../lex';
import { AstMatcher } from '../types';

describe('Lexical analysis', () => {
  let terms: string[];
  let fuzzes: number[];
  let boosts: number[];

  function noMatch() {
    return false;
  }

  function parseTerm(term: string, fuzz: number, boost: number): AstMatcher {
    terms.push(term);
    fuzzes.push(fuzz);
    boosts.push(boost);

    return noMatch;
  }

  beforeEach(() => {
    terms = [];
    fuzzes = [];
    boosts = [];
  });

  it('should lex single terms', () => {
    const array = generateLexArray('safe', parseTerm);
    expect(terms).toEqual(['safe']);
    expect(fuzzes).toEqual([0]);
    expect(boosts).toEqual([1]);
    expect(array).toEqual([noMatch]);
  });

  it('should lex single terms with fuzzing', () => {
    const array = generateLexArray('safe~4', parseTerm);
    expect(terms).toEqual(['safe']);
    expect(fuzzes).toEqual([4]);
    expect(boosts).toEqual([1]);
    expect(array).toEqual([noMatch]);
  });

  it('should lex single terms with boosting', () => {
    const array = generateLexArray('safe^2', parseTerm);
    expect(terms).toEqual(['safe']);
    expect(fuzzes).toEqual([0]);
    expect(boosts).toEqual([2]);
    expect(array).toEqual([noMatch]);
  });

  it('should lex quoted single terms', () => {
    const array = generateLexArray('"safe"', parseTerm);
    expect(terms).toEqual(['"safe"']);
    expect(fuzzes).toEqual([0]);
    expect(boosts).toEqual([1]);
    expect(array).toEqual([noMatch]);
  });

  it('should lex multiple terms connected by AND', () => {
    const array = generateLexArray('safe AND solo', parseTerm);
    expect(terms).toEqual(['safe', 'solo']);
    expect(fuzzes).toEqual([0, 0]);
    expect(boosts).toEqual([1, 1]);
    expect(array).toEqual([noMatch, noMatch, 'and_op']);
  });

  it('should lex multiple terms connected by OR', () => {
    const array = generateLexArray('safe OR solo', parseTerm);
    expect(terms).toEqual(['safe', 'solo']);
    expect(fuzzes).toEqual([0, 0]);
    expect(boosts).toEqual([1, 1]);
    expect(array).toEqual([noMatch, noMatch, 'or_op']);
  });

  it('should prioritize AND over OR', () => {
    const array = generateLexArray('safe OR solo AND fluttershy', parseTerm);
    expect(terms).toEqual(['safe', 'solo', 'fluttershy']);
    expect(array).toEqual([noMatch, noMatch, noMatch, 'and_op', 'or_op']);
  });

  it('should override ordering when using parenthetical expressions', () => {
    const array = generateLexArray('(safe OR solo) AND fluttershy', parseTerm);
    expect(terms).toEqual(['safe', 'solo', 'fluttershy']);
    expect(fuzzes).toEqual([0, 0, 0]);
    expect(boosts).toEqual([1, 1, 1]);
    expect(array).toEqual([noMatch, noMatch, 'or_op', noMatch, 'and_op']);
  });

  it('should lex unary NOT', () => {
    const array = generateLexArray('NOT safe', parseTerm);
    expect(terms).toEqual(['safe']);
    expect(array).toEqual([noMatch, 'not_op']);
  });

  it('should prioritize NOT over AND', () => {
    const array = generateLexArray('NOT safe AND solo', parseTerm);
    expect(terms).toEqual(['safe', 'solo']);
    expect(array).toEqual([noMatch, 'not_op', noMatch, 'and_op']);
  });

  it('should prioritize NOT over OR', () => {
    const array = generateLexArray('NOT safe OR solo', parseTerm);
    expect(terms).toEqual(['safe', 'solo']);
    expect(array).toEqual([noMatch, 'not_op', noMatch, 'or_op']);
  });

  it('should allow group negation', () => {
    const array = generateLexArray('NOT (safe OR solo)', parseTerm);
    expect(terms).toEqual(['safe', 'solo']);
    expect(array).toEqual([noMatch, noMatch, 'or_op', 'not_op']);
  });

  it('should allow NOT expressions inside terms', () => {
    const array = generateLexArray('this NOT that', parseTerm);
    expect(terms).toEqual(['this NOT that']);
    expect(array).toEqual([noMatch]);
  });

  it('should allow parenthetical expressions inside terms', () => {
    const array = generateLexArray('rose (flower)', parseTerm);
    expect(terms).toEqual(['rose (flower)']);
    expect(array).toEqual([noMatch]);
  });

  it('should handle fuzz expressions in place of terms', () => {
    const array = generateLexArray('~2', parseTerm);
    expect(terms).toEqual(['~2']);
    expect(array).toEqual([noMatch]);
  });

  it('should handle boost expressions in place of terms', () => {
    const array = generateLexArray('^2', parseTerm);
    expect(terms).toEqual(['^2']);
    expect(array).toEqual([noMatch]);
  });

  it('should handle fuzz expressions in terms', () => {
    const array = generateLexArray('two~2~two', parseTerm);
    expect(terms).toEqual(['two~2~two']);
    expect(array).toEqual([noMatch]);
  });

  it('should handle boost expressions in terms', () => {
    const array = generateLexArray('two^2^two', parseTerm);
    expect(terms).toEqual(['two^2^two']);
    expect(array).toEqual([noMatch]);
  });

  it('should handle quotes in terms', () => {
    const array = generateLexArray('a "quoted" expression', parseTerm);
    expect(terms).toEqual(['a "quoted" expression']);
    expect(array).toEqual([noMatch]);
  });

  it('should allow extra spaces in terms', () => {
    const array = generateLexArray('twilight  sparkle', parseTerm);
    expect(terms).toEqual(['twilight  sparkle']);
    expect(array).toEqual([noMatch]);
  });

  it('should collapse consecutive AND expressions', () => {
    const array = generateLexArray('safe AND solo AND fluttershy AND applejack', parseTerm);
    expect(terms).toEqual(['safe', 'solo', 'fluttershy', 'applejack']);
    expect(array).toEqual([noMatch, noMatch, 'and_op', noMatch, 'and_op', noMatch, 'and_op']);
  });

  it('should collapse consecutive OR expressions', () => {
    const array = generateLexArray('safe OR solo OR fluttershy OR applejack', parseTerm);
    expect(terms).toEqual(['safe', 'solo', 'fluttershy', 'applejack']);
    expect(array).toEqual([noMatch, noMatch, 'or_op', noMatch, 'or_op', noMatch, 'or_op']);
  });

  it('should mark error on mismatched parentheses', () => {
    expect(() => generateLexArray('(safe OR solo AND fluttershy', parseTerm)).toThrow('Mismatched parentheses.');
    // expect(() => generateLexArray(')bad', parseTerm).error).toThrow('Mismatched parentheses.');
  });
});
