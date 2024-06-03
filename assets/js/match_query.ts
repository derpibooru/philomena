import { defaultMatcher } from './query/matcher';
import { generateLexArray, generateLexResult } from './query/lex';
import { parseTokens } from './query/parse';
import { getAstMatcherForTerm } from './query/term';

function parseWithDefaultMatcher(term: string, fuzz: number) {
  return getAstMatcherForTerm(term, fuzz, defaultMatcher);
}

export function parseSearch(query: string) {
  const tokens = generateLexArray(query, parseWithDefaultMatcher);
  return parseTokens(tokens);
}

export function getTermContexts(query: string) {
  return generateLexResult(query, parseWithDefaultMatcher).termContexts;
}
