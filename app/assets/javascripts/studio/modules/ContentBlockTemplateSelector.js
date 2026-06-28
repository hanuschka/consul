App.ContentBlockEditor.TemplateSelector = {
  currentContentBlockId: null,
  selectionMode: "add",
  replaceTargetWrapper: null,

  initialize() {
    const $document = $(document);
    $document.on("click", ".js-show-content-block-templates", this.handleOpenTemplateSelector.bind(this));
    $document.on("click", ".js-open-template-selector-for-replace", this.handleOpenTemplateSelectorForReplace.bind(this));
    $document.on("click", ".js-copy-content-block-template", this.handleCopyTemplate.bind(this));
  },

  handleOpenTemplateSelector(e) {
    const button = e.currentTarget;
    const isAtTop = button.closest(".js-add-content-block-at-top") !== null;
    const wrapper = App.ContentBlockEditor.DomHelpers.getParentContentBlockWrapper(button);

    this.selectionMode = "add";
    this.replaceTargetWrapper = null;

    App.ContentBlockEditor.Crud.addContentBlockAfter = wrapper;
    App.ContentBlockEditor.Crud.addContentBlockAtTop = isAtTop;
    App.ContentBlockEditor.TemplateSelector.currentContentBlockId = wrapper ? wrapper.dataset.contentBlockId : null;

    const section = this.detectSection(wrapper);
    this.openDialog(section)
  },

  handleOpenTemplateSelectorForReplace(e) {
    const wrapper = App.ContentBlockEditor.DomHelpers.getParentContentBlockWrapper(e.currentTarget);

    this.selectionMode = "replace";
    this.replaceTargetWrapper = wrapper;

    const section = this.detectSection(wrapper);
    this.openDialog(section)
  },

  detectSection(wrapper) {
    const contentBlocksList = document.querySelector(".js-content-blocks-list");

    if (contentBlocksList && contentBlocksList.dataset.templateSection) {
      return contentBlocksList.dataset.templateSection
    }

    if (!wrapper) return "projekt_page"
    if (wrapper.closest("aside, .sidebar, footer")) return "sidebar_and_footer"

    return "projekt_page"
  },

  handleCopyTemplate(e) {
    e.stopPropagation();
    e.preventDefault();
    const templateItem = e.currentTarget.closest('.custom-content-template--item');
    this.copyContentBlockTemplate(templateItem)
  },

  openDialog(section) {
    App.ContentBlockTemplatesSelector.loadTemplatesContent(section);
    App.SharedModal.open("contentBlockTemplatesModal");
  },

  closeDialog() {
    const modal = document.getElementById("contentBlockTemplatesModal");

    if (modal.open) {
      App.SharedModal.closeById("contentBlockTemplatesModal");
    }
  },

  setContentBlockTemplates(params) {
    const initialTemplatesContainer = document.querySelector(".js-content-block-templates-load-container")
    initialTemplatesContainer.innerHTML = params.templates
  },

  copyContentBlockTemplate(templateItem) {
    const contentTemplate = templateItem.querySelector('.js-content-block-template-content');
    const normalizedContent = ProjektStudio.utils.resetMapEmbeds(contentTemplate.innerHTML.trim());
    const cleanedContainer = ProjektStudio.utils.htmlToDomElement(normalizedContent);

    ProjektStudio.utils.cleanContentForClipboard(cleanedContainer);

    navigator.clipboard.writeText(cleanedContainer.innerHTML).then(() => {
      App.ContentBlockEditor.CopyFeedback.show(templateItem.querySelector('.js-copy-content-block-template'));
    })
  }
};
