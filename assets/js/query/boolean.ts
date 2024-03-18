import { AstMatcher } from './types';

export function matchAny(...matchers: AstMatcher[]): AstMatcher {
  return (e: HTMLElement) => matchers.some(matcher => matcher(e));
}

export function matchAll(...matchers: AstMatcher[]): AstMatcher {
  return (e: HTMLElement) => matchers.every(matcher => matcher(e));
}

export function matchNot(matcher: AstMatcher): AstMatcher {
  return (e: HTMLElement) => !matcher(e);
}

export function matchNone(): AstMatcher {
  return () => false;
}
