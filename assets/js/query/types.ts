export type TermType = 'number' | 'date' | 'literal' | 'my';
export type RangeQualifier = 'gt' | 'gte' | 'lt' | 'lte';
export type RangeEqualQualifier = RangeQualifier | 'eq';

export type FieldValue = string;
export type FieldName = string;
export type FieldMatcher = (value: FieldValue, name: FieldName, documentId: number) => boolean;

export type AstMatcher = (e: HTMLElement) => boolean;
export type TokenList = (string | AstMatcher)[];

export class ParseError extends Error {}
