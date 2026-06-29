App.Studio.ContentBlocks.TemplateSelector = {
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
    const wrapper = App.Studio.ContentBlocks.DomHelpers.getParentContentBlockWrapper(button);

    this.selectionMode = "add";
    this.replaceTargetWrapper = null;

    App.Studio.ContentBlocks.Crud.addContentBlockAfter = wrapper;
    App.Studio.ContentBlocks.Crud.addContentBlockAtTop = isAtTop;
    App.Studio.ContentBlocks.TemplateSelector.currentContentBlockId = wrapper ? wrapper.dataset.contentBlockId : null;

    const section = this.detectSection(wrapper);
    this.openDialog(section)
  },

  handleOpenTemplateSelectorForReplace(e) {
    const wrapper = App.Studio.ContentBlocks.DomHelpers.getParentContentBlockWrapper(e.currentTarget);

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
    const normalizedContent = App.Studio.utils.resetMapEmbeds(contentTemplate.innerHTML.trim());
    const cleanedContainer = App.Studio.utils.htmlToDomElement(normalizedContent);

    App.Studio.utils.cleanContentForClipboard(cleanedContainer);

    navigator.clipboard.writeText(cleanedContainer.innerHTML).then(() => {
      App.Studio.ContentBlocks.CopyFeedback.show(templateItem.querySelector('.js-copy-content-block-template'));
    })
  }
};
