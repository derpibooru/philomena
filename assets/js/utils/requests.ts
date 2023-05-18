// Request Utils

type HttpMethod = 'GET' | 'POST' | 'PUT' | 'PATCH';

export function fetchJson(verb: HttpMethod, endpoint: string, body?: Record<string, unknown>): Promise<Response> {
  const data: RequestInit = {
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

export function fetchHtml(endpoint: string): Promise<Response> {
  return fetch(endpoint, {
    credentials: 'same-origin',
    headers: {
      'x-csrf-token': window.booru.csrfToken,
      'x-requested-with': 'xmlhttprequest'
    },
  });
}

export function handleError(response: Response): Response {
  if (!response.ok) {
    throw new Error('Received error from server');
  }
  return response;
}
