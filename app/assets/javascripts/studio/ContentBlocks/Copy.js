App.Studio.ContentBlocks.Copy = {
  initialize() {
    this.initEventListeners();
  },

  initEventListeners() {
    const $document = $(document);
    $document.on("click", ".js-copy-current-content-block", this.handleCopyContentBlock.bind(this));
  },

  handleCopyContentBlock(e) {
    const { contentBlock } = App.Studio.ContentBlocks.DomHelpers.getContentBlockAndWrapper(e.target);

    if (contentBlock) {
      this.copyContentBlockToClipboard(contentBlock, e.currentTarget);
    }
  },

  copyContentBlockToClipboard(contentBlock, button) {
    const clone = contentBlock.cloneNode(true);
    this.stripSimpleEditModeControls(clone);
    App.Studio.utils.cleanContentForClipboard(clone);
    const contentBlockHTML = clone.innerHTML.trim();

    navigator.clipboard.writeText(contentBlockHTML).then(() => {
      App.Studio.ContentBlocks.CopyFeedback.show(button);
    });
  },

  stripSimpleEditModeControls(clone) {
    clone.querySelectorAll(".js-content-block--list-control").forEach((el) => el.remove());

    clone.querySelectorAll(".js-content-block-link-wrapper").forEach((wrapper) => {
      const link = wrapper.querySelector("a");
      if (link) wrapper.parentNode.insertBefore(link, wrapper);
      wrapper.remove();
    });

    clone.querySelectorAll("a.js-content-block-disable-link-click").forEach((a) => {
      a.classList.remove("js-content-block-disable-link-click");
    });

    clone.querySelectorAll("a.glightbox-disabled").forEach((a) => {
      a.classList.remove("glightbox-disabled", "glightbox-link");
      a.classList.add("glightbox");
    });

    clone.removeAttribute("contenteditable");
    clone.querySelectorAll("[contenteditable]").forEach((el) => el.removeAttribute("contenteditable"));
  }
};
