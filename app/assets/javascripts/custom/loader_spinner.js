(function() {
  "use strict";

  App.LoaderSpinner = {
    SHOW_CLASS: "show-loader",

    initialize() {
    },

    show(container) {
      $(container).addClass(this.SHOW_CLASS);
    },

    hide(container) {
      $(container).removeClass(this.SHOW_CLASS);
    }
  };
}).call(this);
