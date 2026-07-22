App.Studio.ContentBlocks.Render = {
  initialize() {
    this.renderContentBlocks()
    window.addEventListener('message', this.handleGlobalMessage.bind(this));
  },

  handleGlobalMessage(event) {
    if (event.data) {
      const data = event.data;
      const params = data.params

      switch(data.event_type) {
        case "setDataForFreshContentBlockOnUI":
          App.Studio.ContentBlocks.Crud.setDataForFreshContentBlock(params);
          break;
        case "updateHTML":
          App.Studio.ContentBlocks.DomHelpers.morphElementHTML(params.selector, params.html)
          break;
      }
    }
  },

  wrapContentBlock(contentBlock, projektId) {
    return App.Studio.Projekt.templateFunctions.addStudioControlsToContentBlock(
      contentBlock.innerHTML,
      {
        projektId,
        contentBlockId: contentBlock.dataset.id
      }
    );
  },

  renderContentBlocks() {
    const projektPageContent =  document.querySelector(".js-custom-page-content--inner");

    if (!projektPageContent) return
    if (projektPageContent.querySelector('.js-content-block-wrapper')) return

    const html = projektPageContent.outerHTML;
    let parser = new DOMParser();
    let doc = parser.parseFromString(html, 'text/html');

    const contentBlocks = Array.from(doc.querySelectorAll('.custom-content-block'));
    let wrappedContentBlocksHtml = '';

    const projektId = App.Studio.Projekt.getCurrentProjektId()

    if (contentBlocks.length > 0) {
      wrappedContentBlocksHtml = Array.from(contentBlocks).map((contentBlock) => {
        const marginBottom = contentBlock.style.marginBottom;
        const wrappedHtml = this.wrapContentBlock(contentBlock, projektId);

        if (marginBottom) {
          const tempDiv = document.createElement('div');
          tempDiv.innerHTML = wrappedHtml;
          const wrapper = tempDiv.querySelector('.custom-content-block-wrapper');
          if (wrapper) {
            wrapper.style.marginBottom = marginBottom;
          }
          return tempDiv.innerHTML;
        }

        return wrappedHtml;
      })
    }

    const newHtml =
      App.Studio.Projekt.templateFunctions.wrapWithContentBlockListHtml(
        wrappedContentBlocksHtml, projektId
      )

    App.Studio.ContentBlocks.DomHelpers.morphElementHTML(".js-custom-page-content--inner", newHtml);

    App.Studio.ContentBlocks.Crud.rerenderContentBlockListControls()
  }
};
