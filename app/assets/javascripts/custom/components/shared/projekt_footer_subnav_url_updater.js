(function() {
  "use strict";
  App.ProjektFooterSubnavUrlUpdater = {
    initialize() {
      const $document = $(document);
      $document.on("click", ".js-projekt-footer-subnav-item", this.handleClick.bind(this));
    },

    handleClick(event) {
      const url = event.currentTarget.href;
      if (url && history.pushState) {
        history.pushState(null, "", url);
      }
    }
  };
}).call(this);
