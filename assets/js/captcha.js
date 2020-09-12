import { delegate, leftClick } from './utils/events';
import { clearEl, makeEl } from './utils/dom';

function insertCaptcha(_event, target) {
  const { parentNode, dataset: { sitekey } } = target;

  const script = makeEl('script', {src: 'https://hcaptcha.com/1/api.js', async: true, defer: true});
  const frame = makeEl('div', {className: 'h-captcha'});

  frame.dataset.sitekey = sitekey;

  clearEl(parentNode);

  parentNode.insertAdjacentElement('beforeend', frame);
  parentNode.insertAdjacentElement('beforeend', script);
}

export function bindCaptchaLinks() {
  delegate(document, 'click', {'.js-captcha': leftClick(insertCaptcha)});
}
