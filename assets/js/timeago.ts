/*
 * Frontend timestamps.
 */

import { assertNotNull } from './utils/assert';

const strings: Record<string, string> = {
  seconds: 'less than a minute',
  minute: 'about a minute',
  minutes: '%d minutes',
  hour: 'about an hour',
  hours: 'about %d hours',
  day: 'a day',
  days: '%d days',
  month: 'about a month',
  months: '%d months',
  year: 'about a year',
  years: '%d years',
};

function distance(time: Date) {
  return new Date().getTime() - time.getTime();
}

function substitute(key: string, amount: number) {
  return strings[key].replace('%d', Math.round(amount).toString());
}

function setTimeAgo(el: HTMLTimeElement) {
  const datetime = el.getAttribute('datetime');
  if (!datetime) {
    return;
  }

  const date = new Date(datetime);
  const distMillis = distance(date);

  const seconds = Math.abs(distMillis) / 1000,
        minutes = seconds / 60,
        hours   = minutes / 60,
        days    = hours / 24,
        months  = days / 30,
        years   = days / 365;

  const words =
    seconds < 45  && substitute('seconds', seconds) ||
    seconds < 90  && substitute('minute', 1)        ||
    minutes < 45  && substitute('minutes', minutes) ||
    minutes < 90  && substitute('hour', 1)          ||
    hours   < 24  && substitute('hours', hours)     ||
    hours   < 42  && substitute('day', 1)           ||
    days    < 30  && substitute('days', days)       ||
    days    < 45  && substitute('month', 1)         ||
    days    < 365 && substitute('months', months)   ||
    years   < 1.5 && substitute('year', 1)          ||
                     substitute('years', years);

  if (!el.getAttribute('title')) {
    el.setAttribute('title', assertNotNull(el.textContent));
  }
  el.textContent = words + (distMillis < 0 ? ' from now' : ' ago');
}

export function timeAgo(args: HTMLTimeElement[] | HTMLCollectionOf<HTMLTimeElement>) {
  for (const el of args) {
    setTimeAgo(el);
  }
}

export function setupTimestamps() {
  timeAgo(document.getElementsByTagName('time'));
  window.setTimeout(setupTimestamps, 60000);
}

window.booru.timeAgo = timeAgo;
