(function() {
  "use strict";
  App.StikyHeader = {
    initialize: function() {
      if (!this.header()) {
        return;
      }

      this.updateHeaderStyles = this.updateHeaderStyles.bind(this)

      // Get the offset position of the header
      this.initialHeaderOffsetY = this.header().offsetTop;
      this.updateHeaderStyles()

      window.onscroll = this.updateHeaderStyles;
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
        } else if (window.pageYOffset <= this.initialHeaderOffsetY) {
          this.header().classList.remove("sticky-header");
        }
      }
    }
  };
}).call(this);
