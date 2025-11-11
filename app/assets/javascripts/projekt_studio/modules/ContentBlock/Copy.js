ProjektStudio.ContentBlock.Copy = {
  initialize() {
    this.initEventListeners();
  },

  initEventListeners() {
    const $document = $(document);
    $document.on("click", ".js-copy-current-content-block", this.handleCopyContentBlock.bind(this));
  },

  handleCopyContentBlock(e) {
    const { contentBlock } = ProjektStudio.ContentBlock.DomHelpers.getContentBlockAndWrapper(e.target);

    if (contentBlock) {
      this.copyContentBlockToClipboard(contentBlock, e.currentTarget);
    }
  },

  copyContentBlockToClipboard(contentBlock, button) {
    const contentBlockHTML = contentBlock.innerHTML.trim();

    navigator.clipboard.writeText(contentBlockHTML).then(() => {
      this.showCopySuccessFeedback(button);
    })
  },

  showCopySuccessFeedback(button) {
    const originalIcon = button.querySelector('i');
    const originalClass = originalIcon.className;

    originalIcon.className = 'fa fas fa-check';
    button.classList.add("-copied");

    setTimeout(() => {
      originalIcon.className = originalClass;
      button.classList.remove("-copied");
    }, 300);
  }
};
