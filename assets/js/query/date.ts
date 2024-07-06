import { assertNotNull } from '../utils/assert';
import { FieldMatcher, ParseError, RangeEqualQualifier } from './types';

type Year = number;
type Month = number;
type Day = number;
type Hours = number;
type Minutes = number;
type Seconds = number;
type AbsoluteDate = [Year, Month, Day, Hours, Minutes, Seconds];
type TimeZoneOffset = [Hours, Minutes];
type PosixTimeMs = number;

function makeMatcher(bottomDate: PosixTimeMs, topDate: PosixTimeMs, qual: RangeEqualQualifier): FieldMatcher {
  // The open-left, closed-right date range specified by the
  // date/time format limits the types of comparisons that are
  // done compared to numeric ranges.
  switch (qual) {
    case 'lte':
      return v => new Date(v).getTime() < topDate;
    case 'gte':
      return v => new Date(v).getTime() >= bottomDate;
    case 'lt':
      return v => new Date(v).getTime() < bottomDate;
    case 'gt':
      return v => new Date(v).getTime() >= topDate;
    case 'eq':
    default:
      return v => {
        const t = new Date(v).getTime();
        return t >= bottomDate && t < topDate;
      };
  }
}

const relativeDateMatch = /(\d+) (second|minute|hour|day|week|month|year)s? ago/;

function makeRelativeDateMatcher(dateVal: string, qual: RangeEqualQualifier): FieldMatcher {
  const match = assertNotNull(relativeDateMatch.exec(dateVal));
  const bounds: Record<string, number> = {
    second: 1000,
    minute: 60000,
    hour: 3600000,
    day: 86400000,
    week: 604800000,
    month: 2592000000,
    year: 31536000000,
  };

  const amount = parseInt(match[1], 10);
  const scale = bounds[match[2]];

  const now = new Date().getTime();
  const bottomDate = new Date(now - amount * scale).getTime();
  const topDate = new Date(now - (amount - 1) * scale).getTime();

  return makeMatcher(bottomDate, topDate, qual);
}

const parseRes: RegExp[] = [
  // year
  /^(\d{4})/,
  // month
  /^-(\d{2})/,
  // day
  /^-(\d{2})/,
  // hour
  /^(?:\s+|T|t)(\d{2})/,
  // minute
  /^:(\d{2})/,
  // second
  /^:(\d{2})/,
];

function makeAbsoluteDateMatcher(dateVal: string, qual: RangeEqualQualifier): FieldMatcher {
  const timeZoneOffset: TimeZoneOffset = [0, 0];
  const timeData: AbsoluteDate = [0, 0, 1, 0, 0, 0];

  const origDateVal: string = dateVal;
  let localDateVal = origDateVal;

  const offsetMatch = /([+-])(\d{2}):(\d{2})$/.exec(localDateVal);
  if (offsetMatch) {
    timeZoneOffset[0] = parseInt(offsetMatch[2], 10);
    timeZoneOffset[1] = parseInt(offsetMatch[3], 10);
    if (offsetMatch[1] === '-') {
      timeZoneOffset[0] *= -1;
      timeZoneOffset[1] *= -1;
    }
    localDateVal = localDateVal.substring(0, localDateVal.length - 6);
  } else {
    localDateVal = localDateVal.replace(/[Zz]$/, '');
  }

  let matchIndex = 0;
  for (; matchIndex < parseRes.length; matchIndex += 1) {
    if (localDateVal.length === 0) {
      break;
    }

    const componentMatch = parseRes[matchIndex].exec(localDateVal);
    if (componentMatch) {
      if (matchIndex === 1) {
        // Months are offset by 1.
        timeData[matchIndex] = parseInt(componentMatch[1], 10) - 1;
      } else {
        // All other components are not offset.
        timeData[matchIndex] = parseInt(componentMatch[1], 10);
      }

      // Truncate string.
      localDateVal = localDateVal.substring(componentMatch[0].length);
    } else {
      throw new ParseError(`Cannot parse date string: ${origDateVal}`);
    }
  }

  if (localDateVal.length > 0) {
    throw new ParseError(`Cannot parse date string: ${origDateVal}`);
  }

  // Apply the user-specified time zone offset. The JS Date constructor
  // is very flexible here.
  timeData[3] -= timeZoneOffset[0];
  timeData[4] -= timeZoneOffset[1];

  const asPosix = (data: AbsoluteDate) => {
    return new Date(Date.UTC.apply(Date, data)).getTime();
  };

  const bottomDate = asPosix(timeData);
  timeData[matchIndex - 1] += 1;
  const topDate = asPosix(timeData);

  return makeMatcher(bottomDate, topDate, qual);
}

export function makeDateMatcher(dateVal: string, qual: RangeEqualQualifier): FieldMatcher {
  if (relativeDateMatch.test(dateVal)) {
    return makeRelativeDateMatcher(dateVal, qual);
  }

  return makeAbsoluteDateMatcher(dateVal, qual);
}
