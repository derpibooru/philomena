/**
 * Fetch captchas.
 */
import { $$, hideEl } from './utils/dom';
import { fetchJson, handleError } from './utils/requests';

function insertCaptcha(checkbox) {
  // Also hide any associated labels
  checkbox.checked = false;
  hideEl(checkbox);
  hideEl($$(`label[for="${checkbox.id}"]`));

  fetchJson('POST', '/captchas')
    .then(handleError)
    .then(r => r.text())
    .then(r => {
      checkbox.insertAdjacentHTML('afterend', r);
      checkbox.parentElement.removeChild(checkbox);
    }).catch(() => {
      checkbox.insertAdjacentHTML('afterend', '<p class="block block--danger">Failed to fetch challenge from server!</p>');
      checkbox.parentElement.removeChild(checkbox);
    });
}

function bindCaptchaLinks() {
  document.addEventListener('click', event => {
    if (event.target && event.target.closest('.js-captcha')) {
      insertCaptcha(event.target.closest('.js-captcha'));
    }
  });
}

export { bindCaptchaLinks };
