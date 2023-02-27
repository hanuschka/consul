(function() {
  "use strict";
  App.NonBlockRemoteLinks = {
    initialize: function() {
      // $("body").on("click", "a[data-nonblock-remote='true']", this.handleLinkClick.bind(this));
      $("a[data-nonblock-remote='true']").on("click", this.handleLinkClick.bind(this));
    },

    handleLinkClick: function(e) {
      e.preventDefault();

      $.get(e.currentTarget.href)
    }
  }
}).call(this);
