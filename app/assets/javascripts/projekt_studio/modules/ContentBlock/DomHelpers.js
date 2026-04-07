ProjektStudio.ContentBlock.DomHelpers = {
  getParentContentBlockWrapper(element) {
    return element.closest('.js-projekt-content-block-wrapper');
  },

  getContentBlockSectionForId(contentBlockId) {
    return document.querySelector(`.js-projekt-content-block-wrapper[data-content-block-id="${contentBlockId}"]`);
  },

  getContentBlockAndWrapper(element) {
    const contentBlockWrapper = this.getParentContentBlockWrapper(element)

    if (!contentBlockWrapper) return {}

    const contentBlock = contentBlockWrapper.querySelector(".projekt-content-block")

    return { contentBlockWrapper, contentBlock};
  },

  getClosestContentBlock(element) {
    return element.closest(".js-projekt-content-block");
  },

  getContentBlock(element) {
    return element.querySelector(".js-projekt-content-block");
  },

  morphElementHTML(selector, html) {
    const element = document.querySelector(selector);

    element.innerHTML = html;

    setTimeout(() => {
      $(element).foundation();
      ProjektStudio.ContentBlock.DragDrop.initSortable();
      App.ImageGallery.initialize();
    }, 10)
  },

  // HACK to make Foundation re-initialization work for accorions and other foundation ui elements
  // DO NOT DELETE
  reinitPluginElementsAndWidgets(contentBlock) {
    $(contentBlock).foundation();
    App.ImageGallery.initialize();
  },

  isSliderItem(element) {
    return element.classList.contains("orbit-slide")
  },

  scrollToContentBlockTop(contentBlockWrapper) {
    const toolbar = contentBlockWrapper.querySelector('.js-projekt-content-block--toolbar-anchor');
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
  }
};
