(function() {
  "use strict";
  App.ImageGallery = {
    initialize: function() {
      this.setMissingHrefs()
      this.setupGlighbox()
      this.bindScrollbarWidthCapture()
    },

    getFixedElement() {
      return document.querySelector(".topbar-header")
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

      var customLightboxHTML = `<div id="glightbox-body" class="glightbox-container" role="dialog" aria-modal="true" aria-label="Bildansicht" tabindex="-1">
                                  <div class="gloader visible"></div>
                                  <div class="goverlay"></div>
                                  <div class="gcontainer">
                                    <div id="glightbox-slider" class="gslider"></div>
                                    <button class="gnext gbtn" tabindex="0" aria-label="Nächste">{nextSVG}</button>
                                    <button class="gprev gbtn" tabindex="0" aria-label="Vorherige">{prevSVG}</button>
                                    <button class="gclose gbtn" tabindex="0" aria-label="Schließen (ESC)">{closeSVG}</button>
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

          var fixedElement = this.getFixedElement();

          if (fixedElement) {
            var currentPaddingRight = parseFloat(getComputedStyle(fixedElement).paddingRight) || 0;
            fixedElement.dataset.lightboxOriginalPaddingRight = fixedElement.style.paddingRight;
            fixedElement.style.paddingRight = (currentPaddingRight + scrollbarWidth) + "px";
          }
        }

        setTimeout(() => {
          var modal = this.getLightboxContainer();

          if (modal) {
            modal.focus();
          }
        }, 100);

        this.bindFocusTrapKeydown();
      });
      this.lightbox.on('close', () => {
        this.unbindFocusTrapKeydown();

        document.body.style.paddingRight = "";

        var fixedElement = this.getFixedElement();

        if (fixedElement) {
          fixedElement.style.paddingRight = fixedElement.dataset.lightboxOriginalPaddingRight || "";
          delete fixedElement.dataset.lightboxOriginalPaddingRight;
        }

        if (this.triggerElement) {
          this.triggerElement.focus();
          this.triggerElement = null;
        }
      });
      this.lightbox.on('slide_after_load', (data) => {
        this.applySlideAccessibility(data);
      });
    },

    bindFocusTrapKeydown() {
      if (!this.focusTrapKeydownHandler) {
        this.focusTrapKeydownHandler = this.handleFocusTrapKeydown.bind(this);
      }

      document.addEventListener("keydown", this.focusTrapKeydownHandler, true);
    },

    unbindFocusTrapKeydown() {
      if (this.focusTrapKeydownHandler) {
        document.removeEventListener("keydown", this.focusTrapKeydownHandler, true);
      }
    },

    handleFocusTrapKeydown(event) {
      if (event.key !== "Tab" && event.which !== 9) return

      var modal = this.getLightboxContainer();

      if (!modal) return

      var focusable = App.FocusTrap.getFocusableElements(modal);

      if (focusable.length === 0) return

      // Take full control of Tab: stop GLightbox's own keydown handler (which
      // only cycles `.gbtn[data-taborder]` buttons and lets focus escape with
      // the tabindex-based markup used here) and cycle within the lightbox.
      event.preventDefault();
      event.stopImmediatePropagation();

      var currentIndex = focusable.indexOf(document.activeElement);
      var lastIndex = focusable.length - 1;
      var nextIndex;

      if (event.shiftKey) {
        nextIndex = currentIndex <= 0 ? lastIndex : currentIndex - 1;
      } else {
        nextIndex = currentIndex === lastIndex ? 0 : currentIndex + 1;
      }

      focusable[nextIndex].focus();
    },

    getLightboxContainer() {
      return document.querySelector(".glightbox-container.glightbox-clean");
    },

    SLIDE_CAPTION_FALLBACK: "Vergrößerte Ansicht",

    applySlideAccessibility(data) {
      var slideEl = data.slideNode || data.slide;
      if (!slideEl) return

      var slideImg = slideEl.querySelector(".gslide-media img");
      if (!slideImg) return

      var sourceImg = this.getSourceImage(data.trigger);

      slideImg.setAttribute("alt", this.resolveSlideCaptionText(data.trigger, sourceImg));
    },

    getSourceImage(trigger) {
      if (!trigger) return null
      if (trigger.tagName === "IMG") return trigger

      return trigger.querySelector("img")
    },

    resolveSlideCaptionText(trigger, sourceImg) {
      var explicitAlt = trigger ? trigger.getAttribute("data-alt") : null;
      if (explicitAlt) return explicitAlt

      if (sourceImg) {
        if (sourceImg.alt) return sourceImg.alt

        var sourceAriaLabel = sourceImg.getAttribute("aria-label");
        if (sourceAriaLabel) return sourceAriaLabel
      }

      return this.SLIDE_CAPTION_FALLBACK
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
