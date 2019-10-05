/**
 * Request Utils
 */

function fetchJson(verb, endpoint, body) {
  const data = {
    method: verb,
    credentials: 'same-origin',
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': window.booru.csrfToken,
    },
  };

  if (body) {
    body._method = verb;
    data.body = JSON.stringify(body);
  }

  return fetch(endpoint, data);
}

function fetchHtml(endpoint) {
  return fetch(endpoint, {
    credentials: 'same-origin',
    headers: {
      'X-Requested-With': 'XMLHttpRequest',
      'X-CSRF-Token': window.booru.csrfToken,
    },
  });
}

function handleError(response) {
  if (!response.ok) {
    throw new Error('Received error from server');
  }
  return response;
}

export { fetchJson, fetchHtml, handleError };
