(function() {
  "use strict";

  App.HorizontalSlider = {
    DRAG_THRESHOLD: 5,

    create(config) {
      const instance = Object.create(this);
      instance.config = config;
      instance._documentObserver = null;
      return instance;
    },

    initialize() {
      this.scanAndSetup(document.body);
      this.observeDocument();
    },

    initializeFor(element) {
      if (!element) return;

      this.scanAndSetup(element, { reinit: true });
    },

    scanAndSetup(element, options = {}) {
      const roots = element.querySelectorAll(this.config.rootSelector);

      roots.forEach((root) => this.setupRoot(root, options));

      if (element.matches && element.matches(this.config.rootSelector)) {
        this.setupRoot(element, options);
      }
    },

    observeDocument() {
      if (this._documentObserver) return;

      this._documentObserver = new MutationObserver((mutations) => this.handleAddedNodes(mutations));
      this._documentObserver.observe(document.body, { childList: true, subtree: true });
    },

    handleAddedNodes(mutations) {
      const rootsToReinit = new Set();

      mutations.forEach((mutation) => {
        mutation.addedNodes.forEach((node) => this.collectRootsFromAddedNode(node, rootsToReinit));
        mutation.removedNodes.forEach((node) => this.collectRootFromRemovedNode(node, mutation.target, rootsToReinit));
      });

      rootsToReinit.forEach((root) => this.setupRoot(root, { reinit: true }));
    },

    collectRootsFromAddedNode(node, rootsToReinit) {
      if (node.nodeType !== 1) return;

      node.querySelectorAll(this.config.rootSelector).forEach((root) => rootsToReinit.add(root));

      if (node.matches && node.matches(this.config.rootSelector)) {
        rootsToReinit.add(node);
      }

      if (node.matches && node.matches(this.config.slideSelector)) {
        const ancestorRoot = node.closest(this.config.rootSelector);
        if (ancestorRoot) rootsToReinit.add(ancestorRoot);
      }
    },

    collectRootFromRemovedNode(node, mutationTarget, rootsToReinit) {
      if (node.nodeType !== 1) return;
      if (!node.matches || !node.matches(this.config.slideSelector)) return;
      if (!mutationTarget || !mutationTarget.closest) return;

      const ancestorRoot = mutationTarget.closest(this.config.rootSelector);
      if (ancestorRoot) rootsToReinit.add(ancestorRoot);
    },

    setupRoot(root, options = {}) {
      if (options.reinit) {
        root.removeAttribute(this.config.initAttr);
      }

      if (root.getAttribute(this.config.initAttr)) return;

      root.setAttribute(this.config.initAttr, "1");

      this.assignUniqueGallery(root);
      this.bindDrag(root);
      this.buildDots(root);
    },

    assignUniqueGallery(root) {
      const uniq = this.config.galleryPrefix + Math.random().toString(36).slice(2, 8);
      const slides = root.querySelectorAll(this.config.slideSelector);

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

    getViewport(root) {
      return root.querySelector(this.config.viewportSelector);
    },

    getSlides(root) {
      return root.querySelectorAll(this.config.slideSelector);
    },

    buildDots(root) {
      const viewport = this.getViewport(root);
      if (!viewport) return;

      const slides = this.getSlides(root);
      if (slides.length <= 1) return;

      const existing = root.querySelector("." + this.config.dotsClass);
      if (existing) existing.remove();

      const container = document.createElement("nav");
      container.className = this.config.dotsClass;
      container.setAttribute("aria-label", "Slides");
      container.style.cssText = this.config.dotsContainerStyle;

      const dots = [];
      const self = this;

      slides.forEach((slide, index) => {
        const built = self.config.dotBuilder(index);

        built.element.addEventListener("click", (e) => {
          e.preventDefault();
          self.scrollToIndex(viewport, self.getSlides(root), index);
        });

        container.appendChild(built.element);
        dots.push(built);
      });

      this.placeDotsContainer(root, viewport, container);

      root._hsDots = dots;

      this.updateActiveDot(root);

      viewport.addEventListener("scroll", () => {
        if (viewport._hsRaf) cancelAnimationFrame(viewport._hsRaf);
        viewport._hsRaf = requestAnimationFrame(() => this.updateActiveDot(root));
      });
    },

    placeDotsContainer(root, viewport, container) {
      const placement = this.config.dotsPlacement || "root";

      if (typeof placement === "function") {
        placement(root, viewport, container);
        return;
      }

      if (placement === "viewport-parent") {
        viewport.parentNode.appendChild(container);
        return;
      }

      root.appendChild(container);
    },

    updateActiveDot(root) {
      const viewport = this.getViewport(root);
      const slides = this.getSlides(root);
      const dots = root._hsDots;
      if (!viewport || !dots || slides.length === 0) return;

      const activeIndex = this.findActiveIndex(viewport, slides);

      dots.forEach((dot, i) => dot.setActive(i === activeIndex));
    },

    findActiveIndex(viewport, slides) {
      const viewportRect = viewport.getBoundingClientRect();
      const viewportCenter = viewportRect.left + viewportRect.width / 2;
      let bestIndex = 0;
      let bestDist = Infinity;

      slides.forEach((slide, index) => {
        const rect = slide.getBoundingClientRect();
        const center = rect.left + rect.width / 2;
        const dist = Math.abs(center - viewportCenter);

        if (dist < bestDist) {
          bestDist = dist;
          bestIndex = index;
        }
      });

      return bestIndex;
    },

    scrollToIndex(viewport, slides, index) {
      const slide = slides[index];
      if (!slide) return;

      const viewportRect = viewport.getBoundingClientRect();
      const slideRect = slide.getBoundingClientRect();
      const targetScrollLeft = viewport.scrollLeft + (slideRect.left - viewportRect.left);

      const behavior = this.config.scrollBehavior || "smooth";

      if (behavior === "instant" || behavior === "auto") {
        viewport.scrollLeft = targetScrollLeft;
      } else {
        viewport.scrollTo({ left: targetScrollLeft, behavior: behavior });
      }
    },

    bindDrag(root) {
      const viewport = this.getViewport(root);
      if (!viewport) return;

      viewport.style.cursor = "grab";
      viewport.style.userSelect = "none";
      viewport.style.webkitUserSelect = "none";

      const state = {
        active: false,
        startX: 0,
        startScrollLeft: 0,
        dragged: false,
        pointerId: null
      };

      const self = this;

      viewport.addEventListener("pointerdown", (e) => self.onPointerDown(e, viewport, state));
      viewport.addEventListener("pointermove", (e) => self.onPointerMove(e, viewport, state));
      viewport.addEventListener("pointerup", (e) => self.onPointerEnd(e, viewport, root, state));
      viewport.addEventListener("pointercancel", (e) => self.onPointerEnd(e, viewport, root, state));
    },

    onPointerDown(e, viewport, state) {
      if (e.pointerType !== "mouse") return;
      if (e.button !== 0) return;
      if (e.target.closest && e.target.closest(".js-content-block--list-control")) return;

      state.active = true;
      state.dragged = false;
      state.startX = e.clientX;
      state.startScrollLeft = viewport.scrollLeft;
      state.pointerId = e.pointerId;

      viewport.style.cursor = "grabbing";
      viewport.setPointerCapture(e.pointerId);
    },

    onPointerMove(e, viewport, state) {
      if (!state.active) return;
      if (e.pointerId !== state.pointerId) return;

      const dx = e.clientX - state.startX;

      if (!state.dragged && Math.abs(dx) > App.HorizontalSlider.DRAG_THRESHOLD) {
        state.dragged = true;
      }

      if (state.dragged) {
        viewport.scrollLeft = state.startScrollLeft - dx;
        e.preventDefault();
      }
    },

    onPointerEnd(e, viewport, root, state) {
      if (!state.active) return;
      if (e && e.pointerId !== state.pointerId) return;

      const wasDragged = state.dragged;

      state.active = false;
      state.dragged = false;
      viewport.style.cursor = "grab";

      if (state.pointerId !== null && viewport.hasPointerCapture(state.pointerId)) {
        viewport.releasePointerCapture(state.pointerId);
      }

      state.pointerId = null;

      if (!wasDragged) return;

      const suppressor = (ev) => {
        ev.preventDefault();
        ev.stopPropagation();
      };

      viewport.addEventListener("click", suppressor, { capture: true, once: true });
      setTimeout(() => viewport.removeEventListener("click", suppressor, { capture: true }), 300);

      const slides = this.getSlides(root);
      const nearestIndex = this.findActiveIndex(viewport, slides);
      this.scrollToIndex(viewport, slides, nearestIndex);
    }
  };
}).call(this);
