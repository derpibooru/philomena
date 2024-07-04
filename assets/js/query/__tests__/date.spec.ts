import { makeDateMatcher } from '../date';

function daysAgo(days: number) {
  return new Date(Date.now() - days * 86400000).toISOString();
}

describe('Date parsing', () => {
  it('should match relative dates (upper bound)', () => {
    const matcher = makeDateMatcher('3 days ago', 'lte');

    expect(matcher(daysAgo(4), 'created_at', 0)).toBe(true);
    expect(matcher(daysAgo(2), 'created_at', 0)).toBe(false);
  });

  it('should match relative dates (lower bound)', () => {
    const matcher = makeDateMatcher('3 days ago', 'gte');

    expect(matcher(daysAgo(4), 'created_at', 0)).toBe(false);
    expect(matcher(daysAgo(2), 'created_at', 0)).toBe(true);
  });

  it('should match absolute date ranges', () => {
    const ltMatcher = makeDateMatcher('2025', 'lt');
    const gtMatcher = makeDateMatcher('2023', 'gt');

    expect(ltMatcher(new Date(Date.UTC(2025, 5, 21)).toISOString(), 'created_at', 0)).toBe(false);
    expect(ltMatcher(new Date(Date.UTC(2024, 5, 21)).toISOString(), 'created_at', 0)).toBe(true);
    expect(ltMatcher(new Date(Date.UTC(2023, 5, 21)).toISOString(), 'created_at', 0)).toBe(true);

    expect(gtMatcher(new Date(Date.UTC(2025, 5, 21)).toISOString(), 'created_at', 0)).toBe(true);
    expect(gtMatcher(new Date(Date.UTC(2024, 5, 21)).toISOString(), 'created_at', 0)).toBe(true);
    expect(gtMatcher(new Date(Date.UTC(2023, 5, 21)).toISOString(), 'created_at', 0)).toBe(false);
  });

  it('should match absolute dates through years', () => {
    const matcher = makeDateMatcher('2024', 'eq');

    expect(matcher(new Date(Date.UTC(2025, 5, 21)).toISOString(), 'created_at', 0)).toBe(false);
    expect(matcher(new Date(Date.UTC(2024, 5, 21)).toISOString(), 'created_at', 0)).toBe(true);
    expect(matcher(new Date(Date.UTC(2023, 5, 21)).toISOString(), 'created_at', 0)).toBe(false);
  });

  it('should match absolute dates through months', () => {
    const matcher = makeDateMatcher('2024-06', 'eq');

    expect(matcher(new Date(Date.UTC(2024, 6, 21)).toISOString(), 'created_at', 0)).toBe(false);
    expect(matcher(new Date(Date.UTC(2024, 5, 21)).toISOString(), 'created_at', 0)).toBe(true);
    expect(matcher(new Date(Date.UTC(2024, 4, 21)).toISOString(), 'created_at', 0)).toBe(false);
  });

  it('should match absolute dates through days', () => {
    const matcher = makeDateMatcher('2024-06-21', 'eq');

    expect(matcher(new Date(Date.UTC(2024, 5, 22)).toISOString(), 'created_at', 0)).toBe(false);
    expect(matcher(new Date(Date.UTC(2024, 5, 21)).toISOString(), 'created_at', 0)).toBe(true);
    expect(matcher(new Date(Date.UTC(2024, 5, 20)).toISOString(), 'created_at', 0)).toBe(false);
  });

  it('should match absolute dates through hours', () => {
    const matcher = makeDateMatcher('2024-06-21T06', 'eq');

    expect(matcher(new Date(Date.UTC(2024, 5, 21, 7)).toISOString(), 'created_at', 0)).toBe(false);
    expect(matcher(new Date(Date.UTC(2024, 5, 21, 6)).toISOString(), 'created_at', 0)).toBe(true);
    expect(matcher(new Date(Date.UTC(2024, 5, 21, 5)).toISOString(), 'created_at', 0)).toBe(false);
  });

  it('should match absolute dates through minutes', () => {
    const matcher = makeDateMatcher('2024-06-21T06:21', 'eq');

    expect(matcher(new Date(Date.UTC(2024, 5, 21, 6, 22)).toISOString(), 'created_at', 0)).toBe(false);
    expect(matcher(new Date(Date.UTC(2024, 5, 21, 6, 21)).toISOString(), 'created_at', 0)).toBe(true);
    expect(matcher(new Date(Date.UTC(2024, 5, 21, 6, 20)).toISOString(), 'created_at', 0)).toBe(false);
  });

  it('should match absolute dates through seconds', () => {
    const matcher = makeDateMatcher('2024-06-21T06:21:30Z', 'eq');

    expect(matcher(new Date(Date.UTC(2024, 5, 21, 6, 21, 31)).toISOString(), 'created_at', 0)).toBe(false);
    expect(matcher(new Date(Date.UTC(2024, 5, 21, 6, 21, 30)).toISOString(), 'created_at', 0)).toBe(true);
    expect(matcher(new Date(Date.UTC(2024, 5, 21, 6, 21, 29)).toISOString(), 'created_at', 0)).toBe(false);
  });

  it('should match absolute dates through seconds with positive timezone offset', () => {
    const matcher = makeDateMatcher('2024-06-21T06:21:30+01:30', 'eq');

    expect(matcher(new Date(Date.UTC(2024, 5, 21, 4, 51, 31)).toISOString(), 'created_at', 0)).toBe(false);
    expect(matcher(new Date(Date.UTC(2024, 5, 21, 4, 51, 30)).toISOString(), 'created_at', 0)).toBe(true);
    expect(matcher(new Date(Date.UTC(2024, 5, 21, 4, 51, 29)).toISOString(), 'created_at', 0)).toBe(false);
  });

  it('should match absolute dates through seconds with negative timezone offset', () => {
    const matcher = makeDateMatcher('2024-06-21T06:21:30-01:30', 'eq');

    expect(matcher(new Date(Date.UTC(2024, 5, 21, 7, 51, 31)).toISOString(), 'created_at', 0)).toBe(false);
    expect(matcher(new Date(Date.UTC(2024, 5, 21, 7, 51, 30)).toISOString(), 'created_at', 0)).toBe(true);
    expect(matcher(new Date(Date.UTC(2024, 5, 21, 7, 51, 29)).toISOString(), 'created_at', 0)).toBe(false);
  });

  it('should not match malformed absolute date expressions', () => {
    expect(() => makeDateMatcher('2024-06-21T06:21:30+01:3020', 'eq')).toThrow(
      'Cannot parse date string: 2024-06-21T06:21:30+01:3020',
    );
  });

  it('should not match malformed relative date expressions', () => {
    expect(() => makeDateMatcher('3 test failures ago', 'eq')).toThrow('Cannot parse date string: 3 test failures ago');
  });
});
