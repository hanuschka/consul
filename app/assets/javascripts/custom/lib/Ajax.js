window.App.Ajax = {
  post: function(url, data) {
    return this.request("POST", url, data)
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
