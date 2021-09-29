/**
 * Request Utils
 */

function fetchJson(verb, endpoint, body) {
  const data = {
    method: verb,
    credentials: 'same-origin',
    headers: {
      'Content-Type': 'application/json',
      'x-csrf-token': window.booru.csrfToken,
      'x-requested-with': 'xmlhttprequest'
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
      'x-csrf-token': window.booru.csrfToken,
      'x-requested-with': 'xmlhttprequest'
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
