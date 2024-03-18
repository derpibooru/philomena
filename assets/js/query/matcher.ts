import { makeDateMatcher } from './date';
import { makeLiteralMatcher } from './literal';
import { makeNumberMatcher } from './number';
import { makeUserMatcher } from './user';

import { FieldMatcher, RangeEqualQualifier } from './types';

export interface MatcherFactory {
  makeDateMatcher: (dateVal: string, qual: RangeEqualQualifier) => FieldMatcher,
  makeLiteralMatcher: (term: string, fuzz: number, wildcardable: boolean) => FieldMatcher,
  makeNumberMatcher: (term: number, fuzz: number, qual: RangeEqualQualifier) => FieldMatcher,
  makeUserMatcher: (term: string) => FieldMatcher
}

export const defaultMatcher: MatcherFactory = {
  makeDateMatcher,
  makeLiteralMatcher,
  makeNumberMatcher,
  makeUserMatcher,
};
