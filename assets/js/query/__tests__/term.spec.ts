import { getAstMatcherForTerm } from '../term';
import { MatcherFactory, defaultMatcher } from '../matcher';
import { termSpaceToImageField } from '../fields';

function noMatch() {
  return false;
}

class TestMatcherFactory implements MatcherFactory {
  public dateVals: string[];
  public literalVals: string[];
  public numberVals: number[];
  public userVals: string[];

  constructor() {
    this.dateVals = [];
    this.literalVals = [];
    this.numberVals = [];
    this.userVals = [];
  }

  makeDateMatcher(term: string) {
    this.dateVals.push(term);
    return noMatch;
  }

  makeLiteralMatcher(term: string) {
    this.literalVals.push(term);
    return noMatch;
  }

  makeNumberMatcher(term: number) {
    this.numberVals.push(term);
    return noMatch;
  }

  makeUserMatcher(term: string) {
    this.userVals.push(term);
    return noMatch;
  }
}

describe('Search terms', () => {
  let factory: TestMatcherFactory;

  beforeEach(() => {
    factory = new TestMatcherFactory();
  });

  it('should parse the default field', () => {
    getAstMatcherForTerm('default', 0, factory);
    expect(factory.literalVals).toEqual(['default']);
  });

  it('should parse the default field with wildcarding', () => {
    getAstMatcherForTerm('def?ul*', 0, factory);
    expect(factory.literalVals).toEqual(['def?ul*']);
  });

  it('should parse the default field with fuzzing', () => {
    getAstMatcherForTerm('default', 1, factory);
    expect(factory.literalVals).toEqual(['default']);
  });

  it('should parse the default field within quotes', () => {
    getAstMatcherForTerm('"default"', 0, factory);
    expect(factory.literalVals).toEqual(['default']);
  });

  it('should parse exact date field values', () => {
    getAstMatcherForTerm('created_at:2024', 0, factory);
    expect(factory.dateVals).toEqual(['2024']);
  });

  it('should parse ranged date field values', () => {
    getAstMatcherForTerm('created_at.lte:2024', 0, factory);
    getAstMatcherForTerm('created_at.lt:2024', 0, factory);
    getAstMatcherForTerm('created_at.gte:2024', 0, factory);
    getAstMatcherForTerm('created_at.gt:2024', 0, factory);
    expect(factory.dateVals).toEqual(['2024', '2024', '2024', '2024']);
  });

  it('should parse exact number field values', () => {
    getAstMatcherForTerm('width:1920', 0, factory);
    expect(factory.numberVals).toEqual([1920]);
  });

  it('should parse ranged number field values', () => {
    getAstMatcherForTerm('width.lte:1920', 0, factory);
    getAstMatcherForTerm('width.lt:1920', 0, factory);
    getAstMatcherForTerm('width.gte:1920', 0, factory);
    getAstMatcherForTerm('width.gt:1920', 0, factory);
    expect(factory.numberVals).toEqual([1920, 1920, 1920, 1920]);
  });

  it('should parse literal field values', () => {
    getAstMatcherForTerm('source_url:*twitter*', 0, factory);
    expect(factory.literalVals).toEqual(['*twitter*']);
  });

  it('should parse user field values', () => {
    getAstMatcherForTerm('my:upvotes', 0, factory);
    getAstMatcherForTerm('my:downvotes', 0, factory);
    getAstMatcherForTerm('my:faves', 0, factory);
    expect(factory.userVals).toEqual(['upvotes', 'downvotes', 'faves']);
  });

  it('should match document with proper field values', () => {
    const idMatcher = getAstMatcherForTerm('id.lt:1', 0, defaultMatcher);
    const sourceMatcher = getAstMatcherForTerm('source_url:twitter.com', 0, defaultMatcher);

    const idAttribute = termSpaceToImageField.id;
    const sourceUrlAttribute = termSpaceToImageField.source_url;

    const properElement = document.createElement('div');
    properElement.setAttribute(idAttribute, '0');
    properElement.setAttribute(sourceUrlAttribute, 'twitter.com');

    expect(idMatcher(properElement)).toBe(true);
    expect(sourceMatcher(properElement)).toBe(true);
  });

  it('should not match document without field values', () => {
    const idMatcher = getAstMatcherForTerm('id.lt:1', 0, defaultMatcher);
    const sourceMatcher = getAstMatcherForTerm('source_url:twitter.com', 0, defaultMatcher);
    const improperElement = document.createElement('div');

    expect(idMatcher(improperElement)).toBe(false);
    expect(sourceMatcher(improperElement)).toBe(false);
  });
});
