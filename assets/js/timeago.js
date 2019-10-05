/*
 * Frontend timestamps.
 */

const strings = {
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

function distance(time) {
  return new Date() - time;
}

function substitute(key, amount) {
  return strings[key].replace('%d', Math.round(amount));
}

function setTimeAgo(el) {
  const date = new Date(el.getAttribute('datetime'));
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
    el.setAttribute('title', el.textContent);
  }
  el.textContent = words + (distMillis < 0 ? ' from now' : ' ago');
}

function timeAgo(args) {
  [].forEach.call(args, el => setTimeAgo(el));
}

function setupTimestamps() {
  timeAgo(document.getElementsByTagName('time'));
  window.setTimeout(setupTimestamps, 60000);
}

export { setupTimestamps };

window.booru.timeAgo = timeAgo;
