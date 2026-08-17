(function() {
  "use strict";

  App.FilterDropdownComponent = {
    SELECTOR: ".js-filter-dropdown-link",

    initialize() {
      const $document = $(document);
      $document.on("click", this.SELECTOR, this.showLoader.bind(this));
      $document.on("ajax:complete", this.SELECTOR, this.hideLoader.bind(this));
    },

    showLoader(event) {
      this.loaderTarget(event).addClass("show-loader");
    },

    hideLoader(event) {
      this.loaderTarget(event).removeClass("show-loader");
    },

    loaderTarget(event) {
      return $($(event.currentTarget).data("loaderTarget"));
    }
  };
}).call(this);
