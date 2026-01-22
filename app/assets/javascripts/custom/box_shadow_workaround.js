(function() {
  "use strict";

  App.BoxShadowWorkaround = {
    initialize: function() {
      this.applyBoxShadows();
    },

    applyBoxShadows: function() {
      document.querySelectorAll('[data-box-shadow]').forEach(element => {
        element.style.boxShadow = element.getAttribute('data-box-shadow');
      });
    }
  };
}).call(this);
