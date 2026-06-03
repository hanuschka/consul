window.App = window.App || {};

window.App.AjaxFetch = {
  get: function(url, data) {
    return this.request({ method: "GET", url: url, data: data });
  },

  post: function(url, data) {
    return this.request({ method: "POST", url: url, data: data });
  },

  patch: function(url, data) {
    return this.request({ method: "PATCH", url: url, data: data });
  },

  delete: function(url, data) {
    return this.request({ method: "DELETE", url: url, data: data });
  },

  request: function(options) {
    const method = (options.method || "GET").toUpperCase();
    const csrfMeta = document.querySelector("meta[name='csrf-token']");
    const csrfToken = csrfMeta ? csrfMeta.getAttribute("content") : "";

    const headers = Object.assign({ "X-CSRF-Token": csrfToken, "Accept": "application/json" }, options.headers || {});
    let url = options.url;
    let body;

    if (method === "GET" || method === "HEAD") {
      if (options.data) {
        const params = options.data instanceof URLSearchParams
          ? options.data
          : new URLSearchParams(options.data);
        url += (url.indexOf("?") === -1 ? "?" : "&") + params.toString();
      }
    } else if (options.data instanceof FormData) {
      body = options.data;
    } else if (options.data !== undefined && options.data !== null) {
      body = JSON.stringify(options.data);
      headers["Content-Type"] = headers["Content-Type"] || "application/json";
    }

    const fetchOptions = {
      method: method,
      credentials: "same-origin",
      headers: headers
    };

    if (body !== undefined) fetchOptions.body = body;

    return fetch(url, fetchOptions).then((response) => {
      const contentType = response.headers.get("Content-Type") || "";
      const parse = contentType.indexOf("application/json") !== -1
        ? response.json()
        : response.text();

      return parse.then((payload) => {
        if (!response.ok) {
          const error = new Error("Request failed: " + response.status);
          error.status = response.status;
          error.response = response;
          error.data = payload;
          throw error;
        }
        return payload;
      });
    });
  }
};
