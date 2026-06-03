(function() {
  "use strict";

  App.MobileFixedBottomActionComponentCustom = {
    initialized: false,
    mediaQuery: null,
    onMediaChange: null,

    initialize: function() {
      if (this.initialized) {
        return;
      }

      var sticky = document.querySelector(".mobile-fixed-on-bottom-action");

      if (!sticky) {
        return;
      }

      this.mediaQuery = window.matchMedia("(max-width: 750px)");
      this.onMediaChange = this.handleMediaChange.bind(this);

      this.onMediaChange();

      if (this.mediaQuery.addEventListener) {
        this.mediaQuery.addEventListener("change", this.onMediaChange);
      } else if (this.mediaQuery.addListener) {
        this.mediaQuery.addListener(this.onMediaChange);
      }

      this.initialized = true;
    },

    handleMediaChange: function() {
      if (this.mediaQuery.matches) {
        document.body.classList.add("has-mobile-sticky-cta");
      } else {
        document.body.classList.remove("has-mobile-sticky-cta");
      }
    }
  };
}).call(this);
