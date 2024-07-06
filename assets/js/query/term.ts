import { MatcherFactory } from './matcher';

import { numberFields, dateFields, literalFields, termSpaceToImageField, defaultField } from './fields';
import { FieldName, FieldMatcher, RangeEqualQualifier, TermType, AstMatcher } from './types';

type RangeInfo = [FieldName, RangeEqualQualifier, TermType];

function normalizeTerm(term: string, wildcardable: boolean) {
  if (!wildcardable) {
    return term.replace('\\"', '"');
  }
  return term.replace(/\\([^*?])/g, '$1');
}

function parseRangeField(field: string): RangeInfo | null {
  if (numberFields.indexOf(field) !== -1) {
    return [field, 'eq', 'number'];
  }

  if (dateFields.indexOf(field) !== -1) {
    return [field, 'eq', 'date'];
  }

  const qual = /^(\w+)\.([lg]te?|eq)$/.exec(field);

  if (qual) {
    const fieldName: FieldName = qual[1];
    const rangeQual = qual[2] as RangeEqualQualifier;

    if (numberFields.indexOf(fieldName) !== -1) {
      return [fieldName, rangeQual, 'number'];
    }

    if (dateFields.indexOf(fieldName) !== -1) {
      return [fieldName, rangeQual, 'date'];
    }
  }

  return null;
}

function makeTermMatcher(term: string, fuzz: number, factory: MatcherFactory): [FieldName, FieldMatcher] {
  let rangeParsing, candidateTermSpace, termCandidate;
  let localTerm = term;
  const wildcardable = fuzz === 0 && !/^"([^"]|\\")+"$/.test(localTerm);

  if (!wildcardable && !fuzz) {
    // Remove quotes around quoted literal term
    localTerm = localTerm.substring(1, localTerm.length - 1);
  }

  localTerm = normalizeTerm(localTerm, wildcardable);

  // N.B.: For the purposes of this parser, boosting effects are ignored.
  const matchArr = localTerm.split(':');

  if (matchArr.length > 1) {
    candidateTermSpace = matchArr[0];
    termCandidate = matchArr.slice(1).join(':');
    rangeParsing = parseRangeField(candidateTermSpace);

    if (rangeParsing) {
      const [fieldName, rangeType, fieldType] = rangeParsing;

      if (fieldType === 'date') {
        return [fieldName, factory.makeDateMatcher(termCandidate, rangeType)];
      }

      return [fieldName, factory.makeNumberMatcher(parseFloat(termCandidate), fuzz, rangeType)];
    } else if (literalFields.indexOf(candidateTermSpace) !== -1) {
      return [candidateTermSpace, factory.makeLiteralMatcher(termCandidate, fuzz, wildcardable)];
    } else if (candidateTermSpace === 'my') {
      return [candidateTermSpace, factory.makeUserMatcher(termCandidate)];
    }
  }

  return [defaultField, factory.makeLiteralMatcher(localTerm, fuzz, wildcardable)];
}

export function getAstMatcherForTerm(term: string, fuzz: number, factory: MatcherFactory): AstMatcher {
  const [fieldName, matcher] = makeTermMatcher(term, fuzz, factory);

  return (e: HTMLElement) => {
    const value = e.getAttribute(termSpaceToImageField[fieldName]) || '';
    const documentId = parseInt(e.getAttribute(termSpaceToImageField.id) || '0', 10);
    return matcher(value, fieldName, documentId);
  };
}
