(function() {
  "use strict";
  App.ImageGallery = {
    initialize: function() {
      this.setMissingHrefs()
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
      if (this.lightbox) {
        this.lightbox.destroy();
      }

      this.scrollbarWidth = this.getScrollbarWidth();

      var customLightboxHTML = `<div id="glightbox-body" class="glightbox-container" role="dialog" aria-modal="true" aria-label="Bildansicht">
                                  <div class="gloader visible"></div>
                                  <div class="goverlay"></div>
                                  <div class="gcontainer">
                                    <div id="glightbox-slider" class="gslider"></div>
                                    <button class="gnext gbtn" tabindex="0" aria-label="Nächste">{nextSVG}</button>
                                    <button class="gprev gbtn" tabindex="0" aria-label="Vorherige">{prevSVG}</button>
                                    <button class="gclose gbtn" tabindex="0" aria-label="Schließen (ESC)">{closeSVG}</button>
                                    <div class="glightbox-esc-hint" aria-live="polite">ESC = Schließen</div>
                                  </div>
                                </div>`;

      let additionalParams = {}

      if (element) {
        additionalParams.elements = element
      }

      this.lightbox = new GLightbox({
        lightboxHTML: customLightboxHTML,
        openEffect: "fade",
        closeEffect: "fade",
        preload: false,
        ...additionalParams
      });

      this.lightbox.on('open', () => {
        this.triggerElement = document.activeElement;

        var stickyHeader = this.getStickyHeader();

        if (stickyHeader) {
          stickyHeader.style.paddingRight = this.scrollbarWidth + "px";
        }

        setTimeout(() => {
          var closeBtn = document.querySelector(".gclose");

          if (closeBtn) {
            closeBtn.focus();
          }
        }, 100);
      });
      this.lightbox.on('close', () => {
        var stickyHeader = this.getStickyHeader();

        if (stickyHeader) {
          stickyHeader.style.paddingRight = "0";
        }

        if (this.triggerElement) {
          this.triggerElement.focus();
          this.triggerElement = null;
        }
      });
      this.lightbox.on('slide_after_load', (data) => {
        this.applySlideAltText(data);
      });
    },

    applySlideAltText(data) {
      var slideEl = data.slideNode || data.slide;
      if (!slideEl) return

      var img = slideEl.querySelector('.gslide-media img');
      if (!img) return

      if (data.trigger) {
        var altText = data.trigger.getAttribute('data-alt');

        if (altText) {
          img.setAttribute('alt', altText);
          return
        }
      }

      if (!img.alt || img.alt === '') {
        img.setAttribute('alt', 'Vergrößerte Ansicht');
      }
    },

    setMissingHrefs: function() {
      document.querySelectorAll(".glightbox:not([href]), .glightbox[href='']").forEach((el) => {
        var img = el.querySelector("img");
        if (img && img.src) {
          el.href = img.src;
        }
      });
    },

  };
}).call(this);
