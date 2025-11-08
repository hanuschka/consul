ProjektStudio.ContentBlock.Render = {
  initialize() {
    this.renderContentBlocks()
    window.addEventListener('message', this.handleGlobalMessage.bind(this));
  },

  handleGlobalMessage(event) {
    if (event.data) {
      const data = ProjektStudio.utils.parseIframeEventData(event.data);
      const params = data.params

      switch(data.event_type) {
        case "Consul.ProjektStudio.updateContentBlockOnUi":
          ProjektStudio.ContentBlock.DtAiEditMode.updateContentBlockOnUi(params);
          break;
        case "setDataForFreshContentBlockOnUI":
          ProjektStudio.ContentBlock.Crud.setDataForFreshContentBlock(params);
          break;
        case "updateHTML":
          ProjektStudio.ContentBlock.DomHelpers.morphElementHTML(params.selector, params.html)
          break;
        case "toggleLockContentBlockEdit":
          ProjektStudio.ContentBlock.DtAiEditMode.toggleLockContentBlockEdit(params.contentBlockId, params.locked)
          break;
      }
    }
  },

  renderContentBlocks() {
    const projektPageContent =  document.querySelector(".js-custom-page-content--inner");

    if (!projektPageContent) return

    const html = projektPageContent.outerHTML;
    let parser = new DOMParser();
    let doc = parser.parseFromString(html, 'text/html');

    const contentBlocks = Array.from(doc.querySelectorAll('.projekt-content-block'));
    let wrappedContentBlocksHtml = '';

    const projektId = ProjektStudio.getCurrentProjektId()

    if (contentBlocks.length > 0) {
      wrappedContentBlocksHtml = Array.from(contentBlocks).map((contentBlock) => {
        return ProjektStudio.templateFunctions.addStudioControlsToContentBlock(
          contentBlock.innerHTML,
          {
            projektId,
            contentBlockId: contentBlock.dataset.id
          }
        );
      }).join("")
    }

    const newHtml =
      ProjektStudio.templateFunctions.wrapWithContentBlockListHtml(
        wrappedContentBlocksHtml, projektId
      )

    ProjektStudio.ContentBlock.DomHelpers.morphElementHTML(".js-custom-page-content--inner", newHtml);
  }
};
