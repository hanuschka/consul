App.ContentBlockEditor.DomHelpers = {
  getParentContentBlockWrapper(element) {
    return element.closest('.js-content-block-wrapper');
  },

  getContentBlockAndWrapper(element) {
    const contentBlockWrapper = this.getParentContentBlockWrapper(element)

    if (!contentBlockWrapper) return {}

    const contentBlock = contentBlockWrapper.querySelector(".projekt-content-block")

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
      App.ContentBlockEditor.DragDrop.initSortable();
      App.ImageGallery.initialize();
    }, 10)
  },

  // HACK to make Foundation re-initialization work for accorions and other foundation ui elements
  // DO NOT DELETE
  reinitPluginElementsAndWidgets(contentBlock) {
    ProjektStudio.utils.removeFoundationIds(contentBlock);
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

  applyDefaultMarginIfMissing(contentBlockWrapper) {
    if (!contentBlockWrapper || contentBlockWrapper.style.marginBottom) return;

    const defaultMargin = ProjektStudio.config.defaultMarginBottom;
    if (!defaultMargin) return;

    contentBlockWrapper.style.marginBottom = `${defaultMargin}px`;
  }
};
