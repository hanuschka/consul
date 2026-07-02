App.Studio.ContentBlocks.DragDrop = {
  initialize() {
  },

  getUpdatePositionUrl(contentBlockWrapper) {
    const customUrl = contentBlockWrapper.dataset.updatePositionUrl;
    if (customUrl) return customUrl;

    const contentBlockId = contentBlockWrapper.dataset.contentBlockId;
    return `/${App.routeNamespace}/projekt_content_blocks/${contentBlockId}/update_position`;
  },

  initSortable() {
    setTimeout(() => {
      const element = document.querySelector(".content-blocks-container");

      new Sortable(
        element, {
          handle: ".js-dnd-handle",
          animation: 150,
          ghostClass: 'content-block-dnd-placeholder',
          dragClass: "content-block-dnd-move",
          scrollSensitivity: 2,
          scrollSpeed: 3,
          draggable: ".js-content-block-wrapper",
          onUpdate: (e) => { this.moveContentBlock(e) },
        });
    }, 200)
  },

  moveContentBlock(e) {
    const newPosition = e.newIndex

    App.Ajax.request({
      url: this.getUpdatePositionUrl(e.item),
      type: "PATCH",
      dataType: "json",
      data: {
        position: newPosition
      }
    })
      .catch((response) => {
        if (response.error && response.error.message) {
          alert(`Fehler beim Speichern des Inhaltsblocks: ${response.error.message}`)
        }
        else {
          alert("Fehler beim Speichern des Inhaltsblocks")
        }
      })
  }
};
