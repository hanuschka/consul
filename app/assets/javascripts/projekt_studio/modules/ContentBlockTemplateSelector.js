ProjektStudio.ContentBlockTemplateSelector = {
  initialize() {
    const $document = $(document);
    $document.on("click", ".js-show-content-block-templates", this.handleOpenTemplateSelector.bind(this));
    $document.on("click", ".js-copy-content-block-template", this.handleCopyTemplate.bind(this));
  },

  handleOpenTemplateSelector(e) {
    ProjektStudio.ContentBlock.Crud.addContentBlockAfter = ProjektStudio.ContentBlock.DomHelpers.getParentContentBlockWrapper(e.currentTarget);
    this.openDialog()
  },

  handleCopyTemplate(e) {
    e.stopPropagation();
    e.preventDefault();
    const templateItem = e.currentTarget.closest('.custom-content-template--item');
    this.copyContentBlockTemplate(templateItem)
  },

  openDialog() {
    $('#contentBlockTemplatesModal').foundation('open');
  },

  closeDialog() {
    $('#contentBlockTemplatesModal').foundation('close');
  },

  setContentBlockTemplates(params) {
    const initialTemplatesContainer = document.querySelector(".js-content-block-templates-load-container")
    initialTemplatesContainer.innerHTML = params.templates
  },

  copyContentBlockTemplate(templateItem) {
    const contentTemplate = templateItem.querySelector('.js-content-block-template-content');
    const templateContent = contentTemplate.innerHTML.trim();

    // Copy to clipboard
    if (navigator.clipboard && window.isSecureContext) {
      // Use modern clipboard API
      navigator.clipboard.writeText(templateContent).then(() => {
        this.showCopySuccessFeedback(templateItem.querySelector('.js-copy-content-block-template'));
      }).catch((err) => {
        console.error('Failed to copy: ', err);
        this.fallbackCopyToClipboard(templateContent, templateItem.querySelector('.js-copy-content-block-template'));
      });
    } else {
      // Fallback for older browsers
      this.fallbackCopyToClipboard(templateContent, templateItem.querySelector('.js-copy-content-block-template'));
    }
  },

  fallbackCopyToClipboard(text, button) {
    const textArea = document.createElement('textarea');
    textArea.value = text;
    textArea.style.position = 'fixed';
    textArea.style.left = '-999999px';
    textArea.style.top = '-999999px';
    document.body.appendChild(textArea);
    textArea.focus();
    textArea.select();

    try {
      document.execCommand('copy');
      this.showCopySuccessFeedback(button);
    } catch (err) {
      console.error('Fallback copy failed: ', err);
      alert('Kopieren fehlgeschlagen. Bitte manuell kopieren.');
    } finally {
      document.body.removeChild(textArea);
    }
  },

  showCopySuccessFeedback(button) {
    const originalIcon = button.querySelector('i');
    const originalClass = originalIcon.className;

    // Change icon to checkmark
    originalIcon.className = 'fa fas fa-check';
    button.classList.add("-copied")

    // Reset after 2 seconds
    setTimeout(() => {
      originalIcon.className = originalClass;
      button.classList.remove("-copied")
    }, 300);
  }
};
