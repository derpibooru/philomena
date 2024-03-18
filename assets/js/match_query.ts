import { defaultMatcher } from './query/matcher';
import { generateLexArray } from './query/lex';
import { parseTokens } from './query/parse';
import { getAstMatcherForTerm } from './query/term';

function parseWithDefaultMatcher(term: string, fuzz: number) {
  return getAstMatcherForTerm(term, fuzz, defaultMatcher);
}

function parseSearch(query: string) {
  const tokens = generateLexArray(query, parseWithDefaultMatcher);
  return parseTokens(tokens);
}

export default parseSearch;
