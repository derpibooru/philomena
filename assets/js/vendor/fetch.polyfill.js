if (typeof window.fetch !== 'function') {
  window.fetch = function fetch(url, options) {
    return new Promise((resolve, reject) => {
      let request = new XMLHttpRequest();

      options = options || {};
      request.open(options.method || 'GET', url);

      for (const i in options.headers) {
        request.setRequestHeader(i, options.headers[i]);
      }

      request.withCredentials = options.credentials === 'include' || options.credentials === 'same-origin';
      request.onload = () => resolve(response());
      request.onerror = reject;

      // IE11 hack: don't send null/undefined
      if (options.body != null)
        request.send(options.body);
      else
        request.send();

      function response() {
        const keys = [], all = [], headers = {};
        let header;

        request.getAllResponseHeaders().replace(/^(.*?):\s*([\s\S]*?)$/gm, (m, key, value) => {
          keys.push(key = key.toLowerCase());
          all.push([key, value]);
          header = headers[key];
          headers[key] = header ? `${header},${value}` : value;
        });

        return {
          ok: (request.status/200|0) === 1,
          status: request.status,
          statusText: request.statusText,
          url: request.responseURL,
          clone: response,
          text: () => Promise.resolve(request.responseText),
          json: () => Promise.resolve(request.responseText).then(JSON.parse),
          blob: () => Promise.resolve(new Blob([request.response])),
          headers: {
            keys: () => keys,
            entries: () => all,
            get: n => headers[n.toLowerCase()],
            has: n => n.toLowerCase() in headers
          }
        };
      }
    });
  };
}
