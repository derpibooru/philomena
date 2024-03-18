import { FieldMatcher } from './types';

function extractValues(v: string, name: string) {
  return name === 'tags' ? v.split(', ') : [v];
}

function makeExactMatcher(term: string): FieldMatcher {
  return (v, name) => {
    const values = extractValues(v, name);

    for (const val of values) {
      if (val.toLowerCase() === term.toLowerCase()) {
        return true;
      }
    }

    return false;
  };
}

function makeWildcardMatcher(term: string): FieldMatcher {
  // Transforms wildcard match into regular expression.
  // A custom NFA with caching may be more sophisticated but not
  // likely to be faster.
  const wildcard = new RegExp(
    `^${term.replace(/([.+^$[\]\\(){}|-])/g, '\\$1')
      .replace(/([^\\]|[^\\](?:\\\\)+)\*/g, '$1.*')
      .replace(/^(?:\\\\)*\*/g, '.*')
      .replace(/([^\\]|[^\\](?:\\\\)+)\?/g, '$1.?')
      .replace(/^(?:\\\\)*\?/g, '.?')}$`, 'i'
  );

  return (v, name) => {
    const values = extractValues(v, name);

    for (const val of values) {
      if (wildcard.test(val)) {
        return true;
      }
    }

    return false;
  };
}

function fuzzyMatch(term: string, targetStr: string, fuzz: number): boolean {
  const targetDistance = fuzz < 1.0 ? targetStr.length * (1.0 - fuzz) : fuzz;
  const targetStrLower = targetStr.toLowerCase();

  // Work vectors, representing the last three populated
  // rows of the dynamic programming matrix of the iterative
  // optimal string alignment calculation.
  let v0: number[] = [];
  let v1: number[] = [];
  let v2: number[] = [];
  let temp: number[];

  for (let i = 0; i <= targetStrLower.length; i += 1) {
    v1.push(i);
  }

  for (let i = 0; i < term.length; i += 1) {
    v2[0] = i;
    for (let j = 0; j < targetStrLower.length; j += 1) {
      const cost = term[i] === targetStrLower[j] ? 0 : 1;
      v2[j + 1] = Math.min(
        // Deletion.
        v1[j + 1] + 1,
        // Insertion.
        v2[j] + 1,
        // Substitution or No Change.
        v1[j] + cost
      );
      if (i > 1 && j > 1 && term[i] === targetStrLower[j - 1] &&
        targetStrLower[i - 1] === targetStrLower[j]) {
        v2[j + 1] = Math.min(v2[j], v0[j - 1] + cost);
      }
    }
    // Rotate dem vec pointers bra.
    temp = v0;
    v0 = v1;
    v1 = v2;
    v2 = temp;
  }

  return v1[targetStrLower.length] <= targetDistance;
}

function makeFuzzyMatcher(term: string, fuzz: number): FieldMatcher {
  return (v, name) => {
    const values = extractValues(v, name);

    for (const val of values) {
      if (fuzzyMatch(term, val, fuzz)) {
        return true;
      }
    }

    return false;
  };
}

export function makeLiteralMatcher(term: string, fuzz: number, wildcardable: boolean): FieldMatcher {
  if (fuzz === 0 && !wildcardable) {
    return makeExactMatcher(term);
  }

  if (!wildcardable) {
    return makeFuzzyMatcher(term, fuzz);
  }

  return makeWildcardMatcher(term);
}
