(function() {
  "use strict";
  App.ProjektFooterSubnavUrlUpdater = {
    initialize() {
      const $document = $(document);
      $document.on("click", ".js-projekt-footer-subnav-item", this.handleClick.bind(this));
    },

    handleClick(event) {
      const section = event.currentTarget.dataset.section;

      if (section && history.pushState) {
        const currentUrl = new URL(window.location.href);
        currentUrl.searchParams.set("section", section);
        history.pushState(null, "", currentUrl.toString());
      }
    }
  };
}).call(this);
