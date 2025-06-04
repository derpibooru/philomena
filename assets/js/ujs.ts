import { assertNotNull, assertNotUndefined } from './utils/assert';
import { $$, makeEl, findFirstTextNode } from './utils/dom';
import { fire, delegate, leftClick } from './utils/events';

const headers = () => ({
  'x-csrf-token': window.booru.csrfToken,
  'x-requested-with': 'XMLHttpRequest',
});

function confirm(event: Event, target: HTMLElement) {
  if (!window.confirm(target.dataset.confirm)) {
    event.preventDefault();
    event.stopImmediatePropagation();
    return false;
  }
}

function disable(_event: Event, target: HTMLAnchorElement | HTMLButtonElement | HTMLInputElement) {
  // failed validations prevent the form from being submitted;
  // stop here or the form will be permanently locked
  if (target.type === 'submit' && target.closest(':invalid') !== null) return;

  // Store what's already there so we don't lose it
  const label = findFirstTextNode<Text>(target);
  if (label) {
    target.dataset.enableWith = assertNotNull(label.nodeValue);
    label.nodeValue = ` ${target.dataset.disableWith}`;
  } else {
    target.dataset.enableWith = target.innerHTML;
    target.innerHTML = assertNotUndefined(target.dataset.disableWith);
  }

  // delay is needed because Safari stops the submit if the button is immediately disabled
  requestAnimationFrame(() => target.setAttribute('disabled', 'disabled'));
}

// you should use button_to instead of link_to[method]!
function linkMethod(event: Event, target: HTMLAnchorElement) {
  event.preventDefault();

  const form = makeEl('form', { action: target.href, method: 'POST' });
  const csrf = makeEl('input', { type: 'hidden', name: '_csrf_token', value: window.booru.csrfToken });
  const method = makeEl('input', { type: 'hidden', name: '_method', value: target.dataset.method });

  document.body.appendChild(form);

  form.appendChild(csrf);
  form.appendChild(method);
  form.submit();
}

function formRemote(event: Event, target: HTMLFormElement) {
  event.preventDefault();

  fetch(target.action, {
    credentials: 'same-origin',
    method: (target.dataset.method || target.method).toUpperCase(),
    headers: headers(),
    body: new FormData(target),
  }).then(response => {
    fire(target, 'fetchcomplete', response);
    if (response && response.status === 300) {
      window.location.reload();
    }
  });
}

function formReset(_event: Event | null, target: HTMLElement) {
  $$<HTMLElement>('[disabled][data-disable-with][data-enable-with]', target).forEach(input => {
    const label = findFirstTextNode(input);
    if (label) {
      label.nodeValue = ` ${input.dataset.enableWith}`;
    } else {
      input.innerHTML = assertNotUndefined(input.dataset.enableWith);
    }
    delete input.dataset.enableWith;
    input.removeAttribute('disabled');
  });
}

function linkRemote(event: Event, target: HTMLAnchorElement) {
  event.preventDefault();

  fetch(target.href, {
    credentials: 'same-origin',
    method: (target.dataset.method || 'get').toUpperCase(),
    headers: headers(),
  }).then(response => fire(target, 'fetchcomplete', response));
}

delegate(document, 'click', {
  'a[data-confirm],button[data-confirm],input[data-confirm]': leftClick(confirm),
  'a[data-disable-with],button[data-disable-with],input[data-disable-with]': leftClick(disable),
  'a[data-method]:not([data-remote])': leftClick(linkMethod),
  'a[data-remote]': leftClick(linkRemote),
});

delegate(document, 'submit', {
  'form[data-remote]': formRemote,
});

delegate(document, 'reset', {
  form: formReset,
});

window.addEventListener('pageshow', () => {
  for (const form of document.forms) {
    formReset(null, form);
  }
});
