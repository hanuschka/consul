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

    navigator.clipboard.writeText(templateContent).then(() => {
      this.showCopySuccessFeedback(templateItem.querySelector('.js-copy-content-block-template'));
    })
  },

  showCopySuccessFeedback(button) {
    const originalIcon = button.querySelector('i');
    const originalClass = originalIcon.className;

    originalIcon.className = 'fa fas fa-check';
    button.classList.add("-copied")

    setTimeout(() => {
      originalIcon.className = originalClass;
      button.classList.remove("-copied")
    }, 300);
  }
};
