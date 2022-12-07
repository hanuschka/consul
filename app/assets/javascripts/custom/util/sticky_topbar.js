(function() {
  "use strict";
  App.StikyHeader = {
    initialized: false,

    initialize: function() {
      if (this.initialized)  {
        return;
      }

      window.onscroll = this.handleScroll.bind(this);

      // Get the navbar
      this.header = document.querySelector(".js-stiky-header");

      // Get the offset position of the header
      this.initialHeaderOffsetY = this.header.offsetTop;
      this.initialized = true;
    },

    handleScroll: function() {
      if (window.pageYOffset > this.initialHeaderOffsetY) {
        this.header.classList.add("-sticky")
      } else {
        this.header.classList.remove("-sticky");
      }
    }
  };
}).call(this);
