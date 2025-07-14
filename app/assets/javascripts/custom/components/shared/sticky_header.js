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

      this.handleScroll = this.handleScroll.bind(this)

      this.handleScroll()

      window.onscroll = this.handleScroll;

      // Get the offset position of the header
      this.initialHeaderOffsetY = this.header().offsetTop;
      this.initialized = true;
    },

    header() {
      return document.querySelector(".js-sticky-header");
    },

    destroy() {
      window.onscroll = null;
    },

    handleScroll: function() {
      if (window.pageYOffset > this.initialHeaderOffsetY) {
        this.header().classList.add("sticky-header");
      } else if (window.pageXOffset === this.initialHeaderOffsetY) {
        this.header().classList.remove("sticky-header");
      }
    }
  };
}).call(this);
