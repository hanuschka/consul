(function() {
  "use strict";
  App.ImageGallery = {
    initialize: function() {
      this.scrollbarWidth = this.getScrollbarWidth();

      var lightbox = new GLightbox({
        openEffect: "fade",
        closeEffect: "fade",
        preload: false
      });

      lightbox.on('open', () => {
        var stickyHeader = this.getStickyHeader();

        if (stickyHeader) {
          stickyHeader.style.paddingRight = this.scrollbarWidth + "px";
        }
      });
      lightbox.on('close', () => {
        var stickyHeader = this.getStickyHeader();

        if (stickyHeader) {
          stickyHeader.style.paddingRight = "0";
        }
      });
    },

    getStickyHeader() {
      return document.querySelector(".js-sticky-header")
    },

    getScrollbarWidth: function() {
      return window.innerWidth - document.documentElement.clientWidth;
    }
  };
}).call(this);
