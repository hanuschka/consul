ProjektStudio.ToggleBackground = {
  initialized: false,

  initialize() {
    if (this.initialized) {
      return;
    }

    const $document = $(document);
    $document.on("click", ".js-toggle-content-background", this.handleToggleClick.bind(this));

    this.initialized = true;
  },

  handleToggleClick(e) {
    const button = e.currentTarget;
    const url = button.dataset.url;
    const currentState = button.dataset.showBackground === "true";
    const newState = !currentState;

    button.dataset.showBackground = newState;
    button.setAttribute("aria-pressed", newState);

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
