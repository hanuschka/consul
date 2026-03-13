ProjektStudio.ContentBlockTemplateSelector = {
  currentContentBlockId: null,

  initialize() {
    const $document = $(document);
    $document.on("click", ".js-show-content-block-templates", this.handleOpenTemplateSelector.bind(this));
    $document.on("click", ".js-copy-content-block-template", this.handleCopyTemplate.bind(this));
  },

  handleOpenTemplateSelector(e) {
    const wrapper = ProjektStudio.ContentBlock.DomHelpers.getParentContentBlockWrapper(e.currentTarget);

    ProjektStudio.ContentBlock.Crud.addContentBlockAfter = wrapper;
    ProjektStudio.ContentBlockTemplateSelector.currentContentBlockId = wrapper ? wrapper.dataset.contentBlockId : null;

    this.openDialog()
  },

  handleCopyTemplate(e) {
    e.stopPropagation();
    e.preventDefault();
    const templateItem = e.currentTarget.closest('.custom-content-template--item');
    this.copyContentBlockTemplate(templateItem)
  },

  openDialog() {
    App.ContentBlockTemplatesSelector.loadTemplatesContent();
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
    const cleanedContent = this.stripAttributesFromContent(contentTemplate.innerHTML.trim());

    navigator.clipboard.writeText(cleanedContent).then(() => {
      this.showCopySuccessFeedback(templateItem.querySelector('.js-copy-content-block-template'));
    })
  },

  stripAttributesFromContent(htmlContent) {
    const tempDiv = document.createElement('div');
    tempDiv.innerHTML = htmlContent;

    const attributesToEmpty = ['data-orbit'];
    const attributesToRemove = ['data-resize', 'id'];
    const allElements = tempDiv.querySelectorAll('*');

    allElements.forEach((element) => {
      attributesToEmpty.forEach((attr) => {
        if (element.hasAttribute(attr)) {
          element.setAttribute(attr, '');
        }
      });

      attributesToRemove.forEach((attr) => {
        element.removeAttribute(attr);
      });
    });

    return tempDiv.innerHTML;
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
