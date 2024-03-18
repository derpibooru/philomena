import { makeNumberMatcher } from '../number';

describe('Number parsing', () => {
  it('should match numbers directly', () => {
    const intMatch = makeNumberMatcher(2067, 0, 'eq');

    expect(intMatch('2066', 'value', 0)).toBe(false);
    expect(intMatch('2067', 'value', 0)).toBe(true);
    expect(intMatch('2068', 'value', 0)).toBe(false);
    expect(intMatch('20677', 'value', 0)).toBe(false);
  });

  it('should match number ranges', () => {
    const ltMatch = makeNumberMatcher(2067, 0, 'lt');
    const lteMatch = makeNumberMatcher(2067, 0, 'lte');
    const gtMatch = makeNumberMatcher(2067, 0, 'gt');
    const gteMatch = makeNumberMatcher(2067, 0, 'gte');

    expect(ltMatch('2066', 'value', 0)).toBe(true);
    expect(ltMatch('2067', 'value', 0)).toBe(false);
    expect(ltMatch('2068', 'value', 0)).toBe(false);
    expect(lteMatch('2066', 'value', 0)).toBe(true);
    expect(lteMatch('2067', 'value', 0)).toBe(true);
    expect(lteMatch('2068', 'value', 0)).toBe(false);
    expect(gtMatch('2066', 'value', 0)).toBe(false);
    expect(gtMatch('2067', 'value', 0)).toBe(false);
    expect(gtMatch('2068', 'value', 0)).toBe(true);
    expect(gteMatch('2066', 'value', 0)).toBe(false);
    expect(gteMatch('2067', 'value', 0)).toBe(true);
    expect(gteMatch('2068', 'value', 0)).toBe(true);
  });

  it('should not match unparsed values', () => {
    const matcher = makeNumberMatcher(2067, 0, 'eq');

    expect(matcher('NaN', 'value', 0)).toBe(false);
    expect(matcher('test', 'value', 0)).toBe(false);
  });

  it('should interpret fuzz as an inclusive range around the value', () => {
    const matcher = makeNumberMatcher(2067, 3, 'eq');

    expect(matcher('2063', 'value', 0)).toBe(false);
    expect(matcher('2064', 'value', 0)).toBe(true);
    expect(matcher('2065', 'value', 0)).toBe(true);
    expect(matcher('2066', 'value', 0)).toBe(true);
    expect(matcher('2067', 'value', 0)).toBe(true);
    expect(matcher('2068', 'value', 0)).toBe(true);
    expect(matcher('2069', 'value', 0)).toBe(true);
    expect(matcher('2070', 'value', 0)).toBe(true);
    expect(matcher('2071', 'value', 0)).toBe(false);
  });
});
