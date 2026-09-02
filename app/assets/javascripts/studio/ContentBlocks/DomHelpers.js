App.Studio.ContentBlocks.DomHelpers = {
  getParentContentBlockWrapper(element) {
    return element.closest('.js-content-block-wrapper');
  },

  getContentBlockAndWrapper(element) {
    const contentBlockWrapper = this.getParentContentBlockWrapper(element)

    if (!contentBlockWrapper) return {}

    const contentBlock = contentBlockWrapper.querySelector(".custom-content-block")

    return { contentBlockWrapper, contentBlock};
  },

  getClosestContentBlock(element) {
    return element.closest(".js-content-block");
  },

  getContentBlock(element) {
    return element.querySelector(".js-content-block");
  },

  reinitFoundationWidgets(element) {
    if (!$.fn.foundation) return

    $(element).foundation();
  },

  morphElementHTML(selector, html) {
    const element = document.querySelector(selector);

    element.innerHTML = html;

    setTimeout(() => {
      this.reinitFoundationWidgets(element);
      App.Studio.ContentBlocks.DragDrop.initSortable();
      App.ImageGallery.initialize();
    }, 10)
  },

  // HACK to make Foundation re-initialization work for accorions and other foundation ui elements
  // DO NOT DELETE
  reinitPluginElementsAndWidgets(contentBlock) {
    App.Studio.utils.removeFoundationIds(contentBlock);
    this.reinitFoundationWidgets(contentBlock);
    App.ImageGallery.initialize();
  },

  isSliderItem(element) {
    return element.classList.contains("orbit-slide")
  },

  scrollToContentBlockTop(contentBlockWrapper) {
    const toolbar = contentBlockWrapper.querySelector('.js-content-block--toolbar-anchor');
    const anchor = toolbar || contentBlockWrapper;
    setTimeout(() => {
      anchor.scrollIntoView({ block: "center" });
    }, 0);
  },

  moveMarginToWrapper(contentBlockWrapper) {
    const contentBlock = this.getContentBlock(contentBlockWrapper);
    if (!contentBlock || !contentBlockWrapper) return;

    const marginBottom = contentBlock.style.marginBottom;
    if (marginBottom && !contentBlockWrapper.style.marginBottom) {
      contentBlockWrapper.style.marginBottom = marginBottom;
      contentBlock.style.marginBottom = '';
    }
  },

  blockStatusConfig() {
    return {
      saved: { modifier: "-saved", icon: "fa-check", text: "Gespeichert", duration: 1100 },
      error: { modifier: "-error", icon: "fa-triangle-exclamation", text: "Fehler beim Speichern", duration: 2500 }
    };
  },

  showBlockStatus(contentBlockWrapper, type) {
    if (!contentBlockWrapper) return

    const config = this.blockStatusConfig()[type];
    const zone = contentBlockWrapper.querySelector(".custom-content-block--toolbar-zone");

    if (!config || !zone) return

    const existing = zone.querySelector(".js-content-block-status");

    if (existing) existing.remove();

    const status = document.createElement("div");
    status.className = `custom-content-block--status js-content-block-status ${config.modifier}`;

    const icon = document.createElement("i");
    icon.className = `fas ${config.icon}`;

    status.appendChild(icon);
    status.appendChild(document.createTextNode(config.text));
    zone.appendChild(status);

    this.scheduleBlockStatusRemoval(status, config.duration);
  },

  scheduleBlockStatusRemoval(status, duration) {
    setTimeout(() => {
      status.classList.add("-leaving");
      setTimeout(() => status.remove(), 200);
    }, duration);
  },

  applyDefaultMarginIfMissing(contentBlockWrapper) {
    if (!contentBlockWrapper || contentBlockWrapper.style.marginBottom) return;

    contentBlockWrapper.style.marginBottom = `${App.Studio.Projekt.getDefaultMarginBottom()}px`;
  }
};
