App.Studio.Projekt.ToggleBackground = {
  initialized: false,

  initialize() {
    if (this.initialized) {
      return;
    }

    const $document = $(document);
    $document.on("change", ".js-toggle-content-background", this.handleToggleChange.bind(this));

    this.initialized = true;
  },

  handleToggleChange(e) {
    const checkbox = e.currentTarget;
    const url = checkbox.dataset.url;
    const newState = checkbox.checked;

    const mainContentCard = document.querySelector(".main-content-card");
    mainContentCard.classList.toggle("-hide-background", !newState);

    App.Ajax.request({
      url: url,
      type: "PATCH",
      dataType: "json"
    })
    .catch(() => {
      console.error("Failed to toggle content background");
    });
  }
};
