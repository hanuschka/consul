(function() {
  "use strict";

  App.SliderThumbsSync = {
    ROOT_SELECTOR: ".js-slider-thumbs-sync",
    MAIN_SELECTOR: ".js-slider-thumbs-sync-main",
    SLIDE_SELECTOR: ".js-slider-thumbs-sync-slide",
    MAIN_IMG_SELECTOR: ".js-slider-thumbs-sync-main-img",
    THUMB_SELECTOR: ".js-slider-thumbs-sync-thumb",
    INIT_ATTR: "data-slider-thumbs-sync-init",

    initialize() {
      this.scanAndSetup(document.body);
      this.observeDocument();
    },

    initializeFor(element) {
      if (!element) return;

      this.scanAndSetup(element, { reinit: true });
    },

    scanAndSetup(element, options = {}) {
      const roots = element.querySelectorAll(this.ROOT_SELECTOR);

      roots.forEach((root) => this.setupRoot(root, options));

      if (element.matches && element.matches(this.ROOT_SELECTOR)) {
        this.setupRoot(element, options);
      }
    },

    observeDocument() {
      if (this.documentObserver) return;

      this.documentObserver = new MutationObserver((mutations) => this.handleAddedNodes(mutations));
      this.documentObserver.observe(document.body, { childList: true, subtree: true });
    },

    handleAddedNodes(mutations) {
      const rootsToReinit = new Set();

      mutations.forEach((mutation) => {
        mutation.addedNodes.forEach((node) => this.collectRootsFromNode(node, rootsToReinit));
      });

      rootsToReinit.forEach((root) => this.setupRoot(root, { reinit: true }));
    },

    collectRootsFromNode(node, rootsToReinit) {
      if (node.nodeType !== 1) return;

      node.querySelectorAll(this.ROOT_SELECTOR).forEach((root) => rootsToReinit.add(root));

      if (node.matches && node.matches(this.ROOT_SELECTOR)) {
        rootsToReinit.add(node);
      }

      const ancestorRoot = node.closest ? node.closest(this.ROOT_SELECTOR) : null;
      if (ancestorRoot) rootsToReinit.add(ancestorRoot);
    },

    setupRoot(root, options = {}) {
      if (options.reinit) {
        root.removeAttribute(this.INIT_ATTR);
        this.disconnectRootObserver(root);
      }

      if (root.getAttribute(this.INIT_ATTR)) return;

      root.setAttribute(this.INIT_ATTR, "1");

      this.assignUniqueGallery(root);
      this.watchMainImages(root);
      this.bindNavigation(root);
    },

    disconnectRootObserver(root) {
      if (root._thumbsSyncObserver) {
        root._thumbsSyncObserver.disconnect();
        root._thumbsSyncObserver = null;
      }
    },

    assignUniqueGallery(root) {
      const uniq = "sts-" + Math.random().toString(36).slice(2, 8);
      const slides = root.querySelectorAll(this.SLIDE_SELECTOR);

      slides.forEach((slide) => {
        const galleryTarget = this.findGalleryTarget(slide);
        galleryTarget.setAttribute("data-gallery", uniq);
      });
    },

    findGalleryTarget(slide) {
      if (slide.classList.contains("glightbox") || slide.classList.contains("glightbox-disabled")) {
        return slide;
      }

      const inner = slide.querySelector(".glightbox, .glightbox-disabled");
      return inner || slide;
    },

    watchMainImages(root) {
      const observer = new MutationObserver((mutations) => {
        mutations.forEach((mutation) => this.handleMainImageMutation(mutation));
      });

      observer.observe(root, {
        attributes: true,
        attributeFilter: ["src", "data-full-image-url"],
        subtree: true
      });

      root._thumbsSyncObserver = observer;
    },

    handleMainImageMutation(mutation) {
      if (mutation.type !== "attributes") return;

      const target = mutation.target;
      if (!target.matches || !target.matches(this.MAIN_IMG_SELECTOR)) return;

      this.syncToThumbByIndex(target);
    },

    syncToThumbByIndex(mainImg) {
      const slide = mainImg.closest(this.SLIDE_SELECTOR);
      if (!slide) return;

      const root = slide.closest(this.ROOT_SELECTOR);
      if (!root) return;

      const slides = Array.from(root.querySelectorAll(this.SLIDE_SELECTOR));
      const idx = slides.indexOf(slide);
      if (idx < 0) return;

      const thumbs = root.querySelectorAll(this.THUMB_SELECTOR);
      const thumb = thumbs[idx];
      if (!thumb) return;

      const smallUrl = mainImg.src;
      const bigUrl = mainImg.dataset.fullImageUrl || smallUrl;

      const thumbImg = thumb.querySelector("img");
      if (thumbImg) thumbImg.src = smallUrl;

      const galleryAnchor = this.findGalleryTarget(slide);
      galleryAnchor.setAttribute("href", bigUrl);
    },

    bindNavigation(root) {
      if (root._thumbsSyncNavBound) return;

      root._thumbsSyncNavBound = true;
      root.addEventListener("click", (e) => this.handleThumbClick(e, root));
    },

    handleThumbClick(e, root) {
      const thumb = e.target.closest(this.THUMB_SELECTOR);

      if (!thumb) return;
      if (!root.contains(thumb)) return;

      e.preventDefault();

      const thumbs = Array.from(root.querySelectorAll(this.THUMB_SELECTOR));
      const idx = thumbs.indexOf(thumb);
      if (idx < 0) return;

      const slides = root.querySelectorAll(this.SLIDE_SELECTOR);
      const slide = slides[idx];
      const mainContainer = root.querySelector(this.MAIN_SELECTOR);

      if (!slide || !mainContainer) return;

      this.scrollContainerToSlide(mainContainer, slide);
    },

    scrollContainerToSlide(mainContainer, slide) {
      const containerRect = mainContainer.getBoundingClientRect();
      const slideRect = slide.getBoundingClientRect();
      const targetScrollLeft = mainContainer.scrollLeft + (slideRect.left - containerRect.left);

      mainContainer.scrollLeft = targetScrollLeft;
    }
  };
}).call(this);
