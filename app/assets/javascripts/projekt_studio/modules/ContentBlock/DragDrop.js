ProjektStudio.ContentBlock.DragDrop = {
  initialize() {
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
          draggable: ".js-projekt-content-block-wrapper",
          onUpdate: (e) => { this.moveContentBlock(e) },
        });
    }, 200)
  },

  moveContentBlock(e) {
    const contentBlockId = e.item.dataset.contentBlockId
    const newPosition = e.newIndex

    $.ajax({
      url: `/${App.routeNamespace}/projekt_content_blocks/${contentBlockId}/update_position`,
      type: "PATCH",
      dataType: "json",
      headers: {
        'X-Embedded-Frame': ProjektStudio.isEmbedded
      },
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
