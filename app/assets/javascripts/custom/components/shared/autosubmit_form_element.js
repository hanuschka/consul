(function() {
  "use strict";
  function debounce(func, wait) {
    let timeout;
    return function(...args) {
      const context = this;
      clearTimeout(timeout);
      timeout = setTimeout(() => func.apply(context, args), wait);
    };
  }

  App.AutosubmitFormElement = {
    initialize: function() {
      $(".js-autosubmit-form input, .js-autosubmit-form select").on("change", debounce(this.submitForm, 500));
    },

    submitForm: function(e) {
      var target = e.target;
      $(target.form).trigger("submit.rails");
    }
  };
}).call(this);
