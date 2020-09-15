import { $$, makeEl, findFirstTextNode } from './utils/dom';
import { fire, delegate, leftClick } from './utils/events';

const headers = () => ({
  'x-csrf-token': window.booru.csrfToken,
  'x-requested-with': 'XMLHttpRequest'
});

function confirm(event, target) {
  if (!window.confirm(target.dataset.confirm)) {
    event.preventDefault();
    event.stopImmediatePropagation();
    return false;
  }
}

function disable(event, target) {
  // failed validations prevent the form from being submitted;
  // stop here or the form will be permanently locked
  if (target.type === 'submit' && target.closest(':invalid') !== null) return;

  // Store what's already there so we don't lose it
  const label = findFirstTextNode(target);
  if (label) {
    target.dataset.enableWith = label.nodeValue;
    label.nodeValue = ` ${target.dataset.disableWith}`;
  }
  else {
    target.dataset.enableWith = target.innerHTML;
    target.innerHTML = target.dataset.disableWith;
  }

  // delay is needed because Safari stops the submit if the button is immediately disabled
  requestAnimationFrame(() => target.disabled = 'disabled');
}

// you should use button_to instead of link_to[method]!
function linkMethod(event, target) {
  event.preventDefault();

  const form   = makeEl('form',  { action: target.href, method: 'POST' });
  const csrf   = makeEl('input', { type: 'hidden', name: '_csrf_token', value: window.booru.csrfToken });
  const method = makeEl('input', { type: 'hidden', name: '_method', value: target.dataset.method });

  document.body.appendChild(form);

  form.appendChild(csrf);
  form.appendChild(method);
  form.submit();
}

function formRemote(event, target) {
  event.preventDefault();

  fetch(target.action, {
    credentials: 'same-origin',
    method: (target.dataset.method || target.method || 'POST').toUpperCase(),
    headers: headers(),
    body: new FormData(target)
  }).then(response => {
    if (response && response.status == 300) {
      window.location.reload(true);
      return;
    }
    fire(target, 'fetchcomplete', response)
  });
}

function formReset(event, target) {
  $$('[disabled][data-disable-with][data-enable-with]', target).forEach(input => {
    const label = findFirstTextNode(input);
    if (label) {
      label.nodeValue = ` ${input.dataset.enableWith}`;
    }
    else { input.innerHTML = target.dataset.enableWith; }
    delete input.dataset.enableWith;
    input.removeAttribute('disabled');
  });
}

function linkRemote(event, target) {
  event.preventDefault();

  fetch(target.href, {
    credentials: 'same-origin',
    method: target.dataset.method.toUpperCase(),
    headers: headers()
  }).then(response =>
    fire(target, 'fetchcomplete', response)
  );
}

delegate(document, 'click', {
  'a[data-confirm],button[data-confirm],input[data-confirm]': leftClick(confirm),
  'a[data-disable-with],button[data-disable-with],input[data-disable-with]': leftClick(disable),
  'a[data-method]:not([data-remote])': leftClick(linkMethod),
  'a[data-remote]': leftClick(linkRemote),
});

delegate(document, 'submit', {
  'form[data-remote]': formRemote
});

delegate(document, 'reset', {
  form: formReset
});

window.addEventListener('pageshow', () => {
  [].forEach.call(document.forms, form => formReset(null, form));
});
