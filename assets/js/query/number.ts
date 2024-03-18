import { FieldMatcher, RangeEqualQualifier } from './types';

export function makeNumberMatcher(term: number, fuzz: number, qual: RangeEqualQualifier): FieldMatcher {
  // Range matching.
  return v => {
    const attrVal = parseFloat(v);

    if (isNaN(attrVal)) {
      return false;
    }

    if (fuzz !== 0) {
      return term - fuzz <= attrVal && term + fuzz >= attrVal;
    }

    switch (qual) {
      case 'lt':
        return attrVal < term;
      case 'gt':
        return attrVal > term;
      case 'lte':
        return attrVal <= term;
      case 'gte':
        return attrVal >= term;
      case 'eq':
      default:
        return attrVal === term;
    }
  };
}
