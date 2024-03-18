import { assertNotNull, assertNotUndefined } from '../utils/assert';
import { AstMatcher, ParseError, TokenList } from './types';

type TokenName = string;
type Token = [TokenName, RegExp];

const tokenList: Token[] = [
  ['fuzz', /^~(?:\d+(\.\d+)?|\.\d+)/],
  ['boost', /^\^[-+]?\d+(\.\d+)?/],
  ['quoted_lit', /^\s*"(?:[^"]|\\")+"/],
  ['lparen', /^\s*\(\s*/],
  ['rparen', /^\s*\)\s*/],
  ['and_op', /^\s*(?:&&|AND)\s+/],
  ['and_op', /^\s*,\s*/],
  ['or_op', /^\s*(?:\|\||OR)\s+/],
  ['not_op', /^\s*NOT(?:\s+|(?=\())/],
  ['not_op', /^\s*[!-]\s*/],
  ['space', /^\s+/],
  ['word', /^(?:\\[\s,()^~]|[^\s,()^~])+/],
  ['word', /^(?:\\[\s,()]|[^\s,()])+/]
];

export type ParseTerm = (term: string, fuzz: number, boost: number) => AstMatcher;

export function generateLexArray(searchStr: string, parseTerm: ParseTerm): TokenList {
  const opQueue: string[] = [],
        groupNegate: boolean[] = [],
        tokenStack: TokenList = [];

  let searchTerm: string | null = null;
  let boostFuzzStr = '';
  let localSearchStr: string = searchStr;
  let negate = false;
  let boost = 1;
  let fuzz = 0;
  let lparenCtr = 0;

  const pushTerm = () => {
    if (searchTerm !== null) {
      // Push to stack.
      tokenStack.push(parseTerm(searchTerm, fuzz, boost));
      // Reset term and options data.
      boost = 1;
      fuzz = 0;
      searchTerm = null;
      boostFuzzStr = '';
      lparenCtr = 0;
    }

    if (negate) {
      tokenStack.push('not_op');
      negate = false;
    }
  };

  while (localSearchStr.length > 0) {
    for (const [tokenName, tokenRe] of tokenList) {
      const match = tokenRe.exec(localSearchStr);

      if (!match) {
        continue;
      }

      const token = match[0];

      if (searchTerm !== null && (['and_op', 'or_op'].indexOf(tokenName) !== -1 || tokenName === 'rparen' && lparenCtr === 0)) {
        pushTerm();
      }

      switch (tokenName) {
        case 'and_op':
          while (opQueue[0] === 'and_op') {
            tokenStack.push(assertNotUndefined(opQueue.shift()));
          }
          opQueue.unshift('and_op');
          break;
        case 'or_op':
          while (opQueue[0] === 'and_op' || opQueue[0] === 'or_op') {
            tokenStack.push(assertNotUndefined(opQueue.shift()));
          }
          opQueue.unshift('or_op');
          break;
        case 'not_op':
          if (searchTerm) {
            // We're already inside a search term, so it does not apply, obv.
            searchTerm += token;
          }
          else {
            negate = !negate;
          }
          break;
        case 'lparen':
          if (searchTerm) {
            // If we are inside the search term, do not error out just yet;
            // instead, consider it as part of the search term, as a user convenience.
            searchTerm += token;
            lparenCtr += 1;
          }
          else {
            opQueue.unshift('lparen');
            groupNegate.push(negate);
            negate = false;
          }
          break;
        case 'rparen':
          if (lparenCtr > 0) {
            searchTerm = assertNotNull(searchTerm) + token;
            lparenCtr -= 1;
          }
          else {
            while (opQueue.length > 0) {
              const op = assertNotUndefined(opQueue.shift());
              if (op === 'lparen') {
                break;
              }
              tokenStack.push(op);
            }
            if (groupNegate.length > 0 && groupNegate.pop()) {
              tokenStack.push('not_op');
            }
          }
          break;
        case 'fuzz':
          if (searchTerm) {
            // For this and boost operations, we store the current match so far
            // to a temporary string in case this is actually inside the term.
            fuzz = parseFloat(token.substring(1));
            boostFuzzStr += token;
          }
          else {
            searchTerm = token;
          }
          break;
        case 'boost':
          if (searchTerm) {
            boost = parseFloat(token.substring(1));
            boostFuzzStr += token;
          }
          else {
            searchTerm = token;
          }
          break;
        case 'quoted_lit':
          if (searchTerm) {
            searchTerm += token;
          }
          else {
            searchTerm = token;
          }
          break;
        case 'word':
          if (searchTerm) {
            if (fuzz !== 0 || boost !== 1) {
              boost = 1;
              fuzz = 0;
              searchTerm += boostFuzzStr;
              boostFuzzStr = '';
            }
            searchTerm += token;
          }
          else {
            searchTerm = token;
          }
          break;
        default:
          // Append extra spaces within search terms.
          if (searchTerm) {
            searchTerm += token;
          }
      }

      // Truncate string and restart the token tests.
      localSearchStr = localSearchStr.substring(token.length);

      // Break since we have found a match.
      break;
    }
  }

  // Append final tokens to the stack.
  pushTerm();

  if (opQueue.indexOf('rparen') !== -1 || opQueue.indexOf('lparen') !== -1) {
    throw new ParseError('Mismatched parentheses.');
  }

  // Concatenatte remaining operators to the token stack.
  tokenStack.push(...opQueue);

  return tokenStack;
}
