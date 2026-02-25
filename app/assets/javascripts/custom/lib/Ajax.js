window.App.Ajax = {
  get: function(url, data) {
    return this.request({ method: "GET", url: url, data: data })
  },

  post: function(url, data) {
    return this.request({ method: "POST", url: url, data: data })
  },

  patch: function(url, data) {
    return this.request({ method: "PATCH", url: url, data: data })
  },

  delete: function(url, data) {
    return this.request({ method: "DELETE", url: url, data: data })
  },

  request: function(options) {
    const csrfToken = $("meta[name='csrf-token']").attr("content");

    const defaultOptions = {
      headers: {
        "X-CSRF-Token": csrfToken
      }
    };

    const mergedOptions = $.extend(true, {}, defaultOptions, options);

    return $.ajax(mergedOptions);
  }
}
