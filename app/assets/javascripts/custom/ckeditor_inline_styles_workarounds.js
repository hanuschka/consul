(function() {
  "use strict";

  App.CkeditorInlineStylesWorkarounds = {
    initialize() {
      this.applyBoxShadows();
    },

    applyBoxShadows() {
      document.querySelectorAll('[data-box-shadow]').forEach(element => {
        element.style.boxShadow = element.getAttribute('data-box-shadow');
      });
    }
  };
}).call(this);
