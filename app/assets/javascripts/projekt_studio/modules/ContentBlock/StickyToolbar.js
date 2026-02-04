ProjektStudio.ContentBlock.StickyToolbar = {
  observers: new Map(),
  mutationObserver: null,

  initialize() {
    this.setupInitialObservers();
    this.watchForEditModeChanges();
  },

  setupInitialObservers() {
    const contentBlockWrappers = document.querySelectorAll(".projekt-content-block-wrapper.-in-edit-mode");
    contentBlockWrappers.forEach(wrapper => {
      this.observeToolbar(wrapper);
    });
  },

  watchForEditModeChanges() {
    const contentBlocksContainer = document.querySelector(".js-content-blocks-list");
    if (!contentBlocksContainer) return;

    this.mutationObserver = new MutationObserver((mutations) => {
      mutations.forEach((mutation) => {
        if (mutation.type === "attributes" && mutation.attributeName === "class") {
          const wrapper = mutation.target;
          if (wrapper.classList.contains("projekt-content-block-wrapper")) {
            if (wrapper.classList.contains("-in-edit-mode")) {
              this.observeToolbar(wrapper);
            } else {
              this.cleanup(wrapper);
            }
          }
        }
      });
    });

    this.mutationObserver.observe(contentBlocksContainer, {
      attributes: true,
      attributeFilter: ["class"],
      subtree: true
    });
  },

  observeToolbar(contentBlockWrapper) {
    const toolbar = contentBlockWrapper.querySelector(".projekt-content-block--toolsets");
    if (!toolbar) return;

    if (this.observers.has(toolbar)) {
      return;
    }

    const relativeContainer = contentBlockWrapper.querySelector(".relative");
    if (!relativeContainer) return;

    const sentinel = document.createElement("div");
    sentinel.className = "sticky-sentinel";
    sentinel.style.height = "1px";
    sentinel.style.position = "relative";
    sentinel.style.top = "-1px";
    sentinel.style.visibility = "hidden";
    sentinel.style.pointerEvents = "none";

    relativeContainer.insertBefore(sentinel, toolbar);

    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.intersectionRatio < 1) {
          toolbar.classList.add("-stuck");
        } else {
          toolbar.classList.remove("-stuck");
        }
      },
      {
        threshold: [1],
        rootMargin: "-90px 0px 0px 0px"
      }
    );

    observer.observe(sentinel);
    this.observers.set(toolbar, { observer, sentinel });
  },

  cleanup(contentBlockWrapper) {
    const toolbar = contentBlockWrapper.querySelector(".projekt-content-block--toolsets");
    if (!toolbar) return;

    const observerData = this.observers.get(toolbar);
    if (observerData) {
      observerData.observer.disconnect();
      if (observerData.sentinel && observerData.sentinel.parentNode) {
        observerData.sentinel.remove();
      }
      this.observers.delete(toolbar);
    }

    toolbar.classList.remove("-stuck");
  }
};
