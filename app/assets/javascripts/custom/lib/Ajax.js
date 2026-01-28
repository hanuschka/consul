window.App.Ajax = {
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
