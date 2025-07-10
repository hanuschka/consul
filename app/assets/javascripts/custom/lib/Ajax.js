window.App.Ajax = {
  post: function(url, data) {
    return this.request("POST", url, data)
  },

  request: function(type, url, data) {
    $.ajax({
      type: type,
      url: url,
      headers: {
        'X-CSRF-TOKEN': this.getCsrfToken()
      },
      data: data
    });
  },

  getCsrfToken: function() {
    var csrfTokenElement =  document.querySelector('meta[name="csrf-token"]');

    if (csrfTokenElement) {
      return csrfTokenElement.getAttribute("content")
    }
    else {
      return null
    }
  }
}
