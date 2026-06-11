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
    button.setAttribute("aria-checked", newState);

    const mainContentCard = document.querySelector(".main-content-card");
    mainContentCard.classList.toggle("-hide-background", !newState);

    const tooltipInstance = $(button).data("zf.tooltip");
    if (tooltipInstance && typeof tooltipInstance.hide === "function") {
      tooltipInstance.hide();
    }
    button.blur();

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
