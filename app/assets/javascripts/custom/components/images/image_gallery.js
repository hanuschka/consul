(function() {
  "use strict";
  App.ImageGallery = {
    initialize: function() {
      this.setMissingHrefs()
      this.setupGlighbox()
      this.bindScrollbarWidthCapture()
    },

    getFixedElements() {
      return document.querySelectorAll(".top-bar-wrapper, .projekt-page--admin-topbar")
    },

    measureScrollbarWidth() {
      return window.innerWidth - document.documentElement.clientWidth;
    },

    bindScrollbarWidthCapture() {
      this.cachedScrollbarWidth = this.measureScrollbarWidth();

      window.addEventListener("resize", () => {
        if (!document.documentElement.classList.contains("glightbox-open")) {
          this.cachedScrollbarWidth = this.measureScrollbarWidth();
        }
      });

      document.addEventListener("pointerdown", (event) => {
        if (event.target.closest(".glightbox")) {
          this.cachedScrollbarWidth = this.measureScrollbarWidth();
        }
      }, true);
    },

    initializeFor(element) {
      this.setupGlighbox(element)
    },

    setupGlighbox(element = null) {
      if (this.lightbox) {
        this.lightbox.destroy();
      }

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

        var scrollbarWidth = this.cachedScrollbarWidth;

        if (scrollbarWidth > 0) {
          document.body.style.paddingRight = scrollbarWidth + "px";

          this.getFixedElements().forEach((el) => {
            var currentPaddingRight = parseFloat(getComputedStyle(el).paddingRight) || 0;
            el.dataset.lightboxOriginalPaddingRight = el.style.paddingRight;
            el.style.paddingRight = (currentPaddingRight + scrollbarWidth) + "px";
          });
        }

        setTimeout(() => {
          var closeBtn = document.querySelector(".gclose");

          if (closeBtn) {
            closeBtn.focus();
          }
        }, 100);
      });
      this.lightbox.on('close', () => {
        document.body.style.paddingRight = "";

        this.getFixedElements().forEach((el) => {
          el.style.paddingRight = el.dataset.lightboxOriginalPaddingRight || "";
          delete el.dataset.lightboxOriginalPaddingRight;
        });

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
