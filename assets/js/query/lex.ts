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
  ['word', /^(?:\\[\s,()]|[^\s,()])+/],
];

export type ParseTerm = (term: string, fuzz: number, boost: number) => AstMatcher;

export interface Range {
  start: number;
  end: number;
}

export interface TermContext {
  range: Range;
  content: string;
}

export interface LexResult {
  tokenList: TokenList;
  termContexts: TermContext[];
  error: ParseError | null;
}

export function generateLexResult(searchStr: string, parseTerm: ParseTerm): LexResult {
  const opQueue: string[] = [];
  const groupNegate: boolean[] = [];

  let searchTerm: string | null = null;
  let boostFuzzStr = '';
  let localSearchStr: string = searchStr;
  let negate = false;
  let boost = 1;
  let fuzz = 0;
  let lparenCtr = 0;

  let termIndex = 0;
  let index = 0;

  const ret: LexResult = {
    tokenList: [],
    termContexts: [],
    error: null,
  };

  const beginTerm = (token: string) => {
    searchTerm = token;
    termIndex = index;
  };

  const endTerm = () => {
    if (searchTerm !== null) {
      // Push to stack.
      ret.tokenList.push(parseTerm(searchTerm, fuzz, boost));

      ret.termContexts.push({
        range: { start: termIndex, end: termIndex + searchTerm.length },
        content: searchTerm,
      });
      // Reset term and options data.
      boost = 1;
      fuzz = 0;
      searchTerm = null;
      boostFuzzStr = '';
      lparenCtr = 0;
    }

    if (negate) {
      ret.tokenList.push('not_op');
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
      const tokenIsBinaryOp = ['and_op', 'or_op'].indexOf(tokenName) !== -1;
      const tokenIsGroupStart = tokenName === 'rparen' && lparenCtr === 0;

      if (searchTerm !== null && (tokenIsBinaryOp || tokenIsGroupStart)) {
        endTerm();
      }

      switch (tokenName) {
        case 'and_op':
          while (opQueue[0] === 'and_op') {
            ret.tokenList.push(assertNotUndefined(opQueue.shift()));
          }
          opQueue.unshift('and_op');
          break;
        case 'or_op':
          while (opQueue[0] === 'and_op' || opQueue[0] === 'or_op') {
            ret.tokenList.push(assertNotUndefined(opQueue.shift()));
          }
          opQueue.unshift('or_op');
          break;
        case 'not_op':
          if (searchTerm) {
            // We're already inside a search term, so it does not apply, obv.
            searchTerm += token;
          } else {
            negate = !negate;
          }
          break;
        case 'lparen':
          if (searchTerm) {
            // If we are inside the search term, do not error out just yet;
            // instead, consider it as part of the search term, as a user convenience.
            searchTerm += token;
            lparenCtr += 1;
          } else {
            opQueue.unshift('lparen');
            groupNegate.push(negate);
            negate = false;
          }
          break;
        case 'rparen':
          if (lparenCtr > 0) {
            searchTerm = assertNotNull(searchTerm) + token;
            lparenCtr -= 1;
          } else {
            while (opQueue.length > 0) {
              const op = assertNotUndefined(opQueue.shift());
              if (op === 'lparen') {
                break;
              }
              ret.tokenList.push(op);
            }
            if (groupNegate.length > 0 && groupNegate.pop()) {
              ret.tokenList.push('not_op');
            }
          }
          break;
        case 'fuzz':
          if (searchTerm) {
            // For this and boost operations, we store the current match so far
            // to a temporary string in case this is actually inside the term.
            fuzz = parseFloat(token.substring(1));
            boostFuzzStr += token;
          } else {
            beginTerm(token);
          }
          break;
        case 'boost':
          if (searchTerm) {
            boost = parseFloat(token.substring(1));
            boostFuzzStr += token;
          } else {
            beginTerm(token);
          }
          break;
        case 'quoted_lit':
          if (searchTerm) {
            searchTerm += token;
          } else {
            beginTerm(token);
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
          } else {
            beginTerm(token);
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
      index += token.length;

      // Break since we have found a match.
      break;
    }
  }

  // Append final tokens to the stack.
  endTerm();

  if (opQueue.indexOf('rparen') !== -1 || opQueue.indexOf('lparen') !== -1) {
    ret.error = new ParseError('Mismatched parentheses.');
  }

  // Concatenate remaining operators to the token stack.
  ret.tokenList.push(...opQueue);

  return ret;
}

export function generateLexArray(searchStr: string, parseTerm: ParseTerm): TokenList {
  const ret = generateLexResult(searchStr, parseTerm);

  if (ret.error) {
    throw ret.error;
  }

  return ret.tokenList;
}
