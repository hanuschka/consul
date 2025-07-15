(function() {
  "use strict";
  App.StikyHeader = {
    initialized: false,

    initialize: function() {
      if (this.initialized) {
        return;
      }

      if (!this.header()) {
        return;
      }

      this.updateHeaderStyles = this.updateHeaderStyles.bind(this)

      // Get the offset position of the header
      this.initialHeaderOffsetY = this.header().offsetTop;
      this.updateHeaderStyles()

      window.onscroll = this.updateHeaderStyles;
      this.initialized = true;
    },

    header() {
      return document.querySelector(".js-sticky-header");
    },

    destroy() {
      window.onscroll = null;
    },

    updateHeaderStyles() {
      if (this.header()) {
        if (window.pageYOffset > this.initialHeaderOffsetY) {
          this.header().classList.add("sticky-header");
        } else if (window.pageXOffset === this.initialHeaderOffsetY) {
          this.header().classList.remove("sticky-header");
        }
      }
    }
  };
}).call(this);
