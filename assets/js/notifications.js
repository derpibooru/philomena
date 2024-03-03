/**
 * Notifications
 */

import { fetchJson, handleError } from './utils/requests';
import { $ } from './utils/dom';
import { delegate } from './utils/events';
import store from './utils/store';

const NOTIFICATION_INTERVAL = 600000,
      NOTIFICATION_EXPIRES = 300000;

function makeRequest(verb) {
  return fetchJson(verb, '/notifications/unread').then(handleError);
}

function bindSubscriptionLinks() {
  delegate(document, 'fetchcomplete', {
    '.js-subscription-link': event => {
      const target = event.target.closest('.js-subscription-target');
      event.detail.text().then(text => {
        target.outerHTML = text;
      });
    }
  });
}

function getNewNotifications() {
  if (document.hidden || !store.hasExpired('notificationCount')) {
    return;
  }

  makeRequest('GET').then(response => response.json()).then(({ notifications }) => {
    updateNotificationTicker(notifications);
    storeNotificationCount(notifications);

    setTimeout(getNewNotifications, NOTIFICATION_INTERVAL);
  });
}

function updateNotificationTicker(notificationCount) {
  const ticker = $('.js-notification-ticker');
  const parsedNotificationCount = Number(notificationCount);

  ticker.dataset.notificationCount = parsedNotificationCount;
  ticker.textContent = parsedNotificationCount;
}


function storeNotificationCount(notificationCount) {
  // The current number of notifications are stored along with the time when the data expires
  store.setWithExpireTime('notificationCount', notificationCount, NOTIFICATION_EXPIRES);
}


function setupNotifications() {
  if (!window.booru.userIsSignedIn) return;

  // Fetch notifications from the server at a regular interval
  setTimeout(getNewNotifications, NOTIFICATION_INTERVAL);

  // Update the current number of notifications based on the latest page load
  storeNotificationCount($('.js-notification-ticker').dataset.notificationCount);

  // Update ticker when the stored value changes - this will occur in all open tabs
  store.watch('notificationCount', updateNotificationTicker);

  bindSubscriptionLinks();
}

export { setupNotifications };
