import { timeAgo, setupTimestamps } from '../timeago';

const epochRfc3339 = '1970-01-01T00:00:00.000Z';

describe('Timeago functionality', () => {
  // TODO: is this robust? do we need e.g. timekeeper to freeze the time?
  function timeAgoWithSecondOffset(offset: number) {
    const utc = new Date(new Date().getTime() + offset * 1000).toISOString();

    const timeEl = document.createElement('time');
    timeEl.setAttribute('datetime', utc);
    timeEl.textContent = utc;

    timeAgo([timeEl]);
    return timeEl.textContent;
  }

  /* eslint-disable no-implicit-coercion */
  it('should parse a time as less than a minute', () => {
    expect(timeAgoWithSecondOffset(-15)).toEqual('less than a minute ago');
    expect(timeAgoWithSecondOffset(+15)).toEqual('less than a minute from now');
  });

  it('should parse a time as about a minute', () => {
    expect(timeAgoWithSecondOffset(-75)).toEqual('about a minute ago');
    expect(timeAgoWithSecondOffset(+75)).toEqual('about a minute from now');
  });

  it('should parse a time as 30 minutes', () => {
    expect(timeAgoWithSecondOffset(-(60 * 30))).toEqual('30 minutes ago');
    expect(timeAgoWithSecondOffset(+(60 * 30))).toEqual('30 minutes from now');
  });

  it('should parse a time as about an hour', () => {
    expect(timeAgoWithSecondOffset(-(60 * 60))).toEqual('about an hour ago');
    expect(timeAgoWithSecondOffset(+(60 * 60))).toEqual('about an hour from now');
  });

  it('should parse a time as about 6 hours', () => {
    expect(timeAgoWithSecondOffset(-(60 * 60 * 6))).toEqual('about 6 hours ago');
    expect(timeAgoWithSecondOffset(+(60 * 60 * 6))).toEqual('about 6 hours from now');
  });

  it('should parse a time as a day', () => {
    expect(timeAgoWithSecondOffset(-(60 * 60 * 36))).toEqual('a day ago');
    expect(timeAgoWithSecondOffset(+(60 * 60 * 36))).toEqual('a day from now');
  });

  it('should parse a time as 25 days', () => {
    expect(timeAgoWithSecondOffset(-(60 * 60 * 24 * 25))).toEqual('25 days ago');
    expect(timeAgoWithSecondOffset(+(60 * 60 * 24 * 25))).toEqual('25 days from now');
  });

  it('should parse a time as about a month', () => {
    expect(timeAgoWithSecondOffset(-(60 * 60 * 24 * 35))).toEqual('about a month ago');
    expect(timeAgoWithSecondOffset(+(60 * 60 * 24 * 35))).toEqual('about a month from now');
  });

  it('should parse a time as 3 months', () => {
    expect(timeAgoWithSecondOffset(-(60 * 60 * 24 * 30 * 3))).toEqual('3 months ago');
    expect(timeAgoWithSecondOffset(+(60 * 60 * 24 * 30 * 3))).toEqual('3 months from now');
  });

  it('should parse a time as about a year', () => {
    expect(timeAgoWithSecondOffset(-(60 * 60 * 24 * 30 * 13))).toEqual('about a year ago');
    expect(timeAgoWithSecondOffset(+(60 * 60 * 24 * 30 * 13))).toEqual('about a year from now');
  });

  it('should parse a time as 5 years', () => {
    expect(timeAgoWithSecondOffset(-(60 * 60 * 24 * 30 * 12 * 5))).toEqual('5 years ago');
    expect(timeAgoWithSecondOffset(+(60 * 60 * 24 * 30 * 12 * 5))).toEqual('5 years from now');
  });
  /* eslint-enable no-implicit-coercion */

  it('should ignore time elements without a datetime attribute', () => {
    const timeEl = document.createElement('time');
    const value = Math.random().toString();

    timeEl.textContent = value;
    timeAgo([timeEl]);

    expect(timeEl.textContent).toEqual(value);
  });

  it('should not reset title attribute if it already exists', () => {
    const timeEl = document.createElement('time');
    const value = Math.random().toString();

    timeEl.setAttribute('datetime', epochRfc3339);
    timeEl.setAttribute('title', value);
    timeAgo([timeEl]);

    expect(timeEl.getAttribute('title')).toEqual(value);
    expect(timeEl.textContent).not.toEqual(epochRfc3339);
  });
});

describe('Automatic timestamps', () => {
  it('should process all timestamps in the document', () => {
    for (let i = 0; i < 5; i += 1) {
      const timeEl = document.createElement('time');
      timeEl.setAttribute('datetime', epochRfc3339);
      timeEl.textContent = epochRfc3339;

      document.documentElement.insertAdjacentElement('beforeend', timeEl);
    }

    setupTimestamps();

    for (const timeEl of document.getElementsByTagName('time')) {
      expect(timeEl.textContent).not.toEqual(epochRfc3339);
    }
  });
});
