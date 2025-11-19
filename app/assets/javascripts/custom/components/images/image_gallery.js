(function() {
  "use strict";
  App.ImageGallery = {
    initialize: function() {
      this.setupGlighbox()
    },

    getStickyHeader() {
      return document.querySelector(".top-bar-wrapper")
    },

    getScrollbarWidth: function() {
      return window.innerWidth - document.documentElement.clientWidth;
    },

    initializeFor(element) {
      this.setupGlighbox(element)
    },

    setupGlighbox(element = null) {
      this.scrollbarWidth = this.getScrollbarWidth();

      var customLightboxHTML = `<div id="glightbox-body" class="glightbox-container">
                                  <div class="gloader visible"></div>
                                  <div class="goverlay"></div>
                                  <div class="gcontainer">
                                    <div id="glightbox-slider" class="gslider"></div>
                                    <button class="gnext gbtn" tabindex="0" aria-label="Nächste" data-customattribute="example">{nextSVG}</button>
                                    <button class="gprev gbtn" tabindex="1" aria-label="Vorherige">{prevSVG}</button>
                                    <button class="gclose gbtn" tabindex="2" aria-label="Schließen">{closeSVG}</button>
                                  </div>
                                </div>`;

      let additionalParams = {}

      if (element) {
        additionalParams.elements = element
      }

      var lightbox = new GLightbox({
        lightboxHTML: customLightboxHTML,
        openEffect: "fade",
        closeEffect: "fade",
        preload: false
        *additionalParams
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
    }

  };
}).call(this);
