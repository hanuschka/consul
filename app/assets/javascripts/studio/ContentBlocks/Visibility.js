// Eye toggle and visibility period of a content block. Both save immediately
// through the block's regular update URL; the server answers with the new
// state (including whether citizens see the block right now), which is then
// re-rendered into the toolbar and the hint.
App.Studio.ContentBlocks.Visibility = {
  currentWrapper: null,

  initialize() {
    const $document = $(document);

    $document.on("click", ".js-content-block-toggle-visibility", this.handleToggleClick.bind(this));
    $document.on("click", ".js-content-block-edit-visibility-period", this.handlePeriodButtonClick.bind(this));
    $document.on("click", ".js-content-block-accept-visibility-period", this.acceptPeriodEdit.bind(this));
    $document.on("click", ".js-content-block-cancel-visibility-period", this.cancelPeriodEdit.bind(this));
    $document.on("click", ".js-content-block-clear-visibility-period", this.clearPeriod.bind(this));
    $document.on("keydown", ".js-content-block-visibility-period-popup", this.handlePopupKeydown.bind(this));
  },

  // Blocks rendered without these data attributes (freshly added, duplicated
  // or AI-created in the studio) start with the column defaults.
  readFromElement(element) {
    const dataset = element ? element.dataset : {};

    return {
      visible: dataset.visible !== "false",
      visibleFrom: dataset.visibleFrom || "",
      visibleUntil: dataset.visibleUntil || "",
      status: dataset.visibilityStatus || "visible"
    };
  },

  fromServerState(state) {
    return {
      visible: state.visible,
      visibleFrom: state.visible_from || "",
      visibleUntil: state.visible_until || "",
      status: state.status
    };
  },

  isPersisted(wrapper) {
    return wrapper && wrapper.dataset.contentBlockId && wrapper.dataset.draft !== "true";
  },

  handleToggleClick(e) {
    e.preventDefault();

    const wrapper = App.Studio.ContentBlocks.DomHelpers.getParentContentBlockWrapper(e.currentTarget);

    if (!this.isPersisted(wrapper)) return

    const button = e.currentTarget;
    const visibility = this.readFromElement(wrapper);

    button.disabled = true;

    this.save(wrapper, { visible: !visibility.visible })
      .catch(() => {
        button.disabled = false;
        App.Studio.ContentBlocks.DomHelpers.showBlockStatus(wrapper, "error");
      });
  },

  // Success re-renders the controls, which also drops any disabled state.
  save(wrapper, data) {
    return App.Ajax
      .request({
        url: App.Studio.ContentBlocks.Crud.getUpdateUrl(wrapper),
        type: "PATCH",
        dataType: "json",
        data: data
      })
      .then((response) => {
        this.applyState(wrapper, this.fromServerState(response.visibility));
        App.Studio.ContentBlocks.DomHelpers.showBlockStatus(wrapper, "saved");
      });
  },

  applyState(wrapper, visibility) {
    const templateFunctions = App.Studio.Projekt.templateFunctions;

    wrapper.dataset.visible = visibility.visible;
    wrapper.dataset.visibleFrom = visibility.visibleFrom;
    wrapper.dataset.visibleUntil = visibility.visibleUntil;
    wrapper.dataset.visibilityStatus = visibility.status;
    wrapper.classList.toggle("-hidden-from-visitors", visibility.status !== "visible");

    this.replaceOwnElement(
      wrapper, ".js-content-block-visibility-controls",
      templateFunctions.contentBlockVisibilityControlsHtml(visibility)
    );
    this.replaceOwnElement(
      wrapper, ".js-content-block-visibility-hint",
      templateFunctions.contentBlockVisibilityHintHtml(visibility)
    );
  },

  // Scoped to the wrapper's own elements: a block's HTML may itself contain
  // markup that matches, e.g. a pasted studio snippet.
  replaceOwnElement(wrapper, selector, html) {
    const element = Array.from(wrapper.querySelectorAll(selector)).find((candidate) => {
      return App.Studio.ContentBlocks.DomHelpers.getParentContentBlockWrapper(candidate) === wrapper;
    });

    if (!element) return

    element.outerHTML = html;
  },

  getPopup() {
    return $(".js-content-block-visibility-period-popup");
  },

  getFromInput() {
    return document.querySelector(".js-content-block-visible-from-input");
  },

  getUntilInput() {
    return document.querySelector(".js-content-block-visible-until-input");
  },

  handlePeriodButtonClick(e) {
    e.preventDefault();

    const button = e.currentTarget;
    const wrapper = App.Studio.ContentBlocks.DomHelpers.getParentContentBlockWrapper(button);

    if (!this.isPersisted(wrapper)) return

    const visibility = this.readFromElement(wrapper);
    const $popup = this.getPopup();

    this.currentWrapper = wrapper;
    this.getFromInput().value = visibility.visibleFrom;
    this.getUntilInput().value = visibility.visibleUntil;
    $popup.find(".js-content-block-visibility-period-hidden-note").prop("hidden", visibility.visible);
    this.showError(null);

    App.Studio.ContentBlocks.SimpleEditMode.EditPopup.show($popup, button);
    this.keepPopupInViewport($popup);

    this.getFromInput().focus();
  },

  // The toolbar sits at the block's right edge, so a popup opened left-aligned
  // to its button would run off the screen.
  keepPopupInViewport($popup) {
    const popup = $popup.get(0);

    if (!popup) return

    const overflow = popup.getBoundingClientRect().right - document.documentElement.clientWidth + 12;

    if (overflow > 0) {
      popup.style.left = `${Math.max(window.scrollX + 12, parseFloat(popup.style.left) - overflow)}px`;
    }
  },

  acceptPeriodEdit(e) {
    e.preventDefault();

    if (!this.currentWrapper) return

    const visibleFrom = this.getFromInput().value;
    const visibleUntil = this.getUntilInput().value;

    // Same-format local timestamps compare correctly as strings.
    if (visibleFrom && visibleUntil && visibleUntil < visibleFrom) {
      this.showError("order");

      return
    }

    this.savePeriod(visibleFrom, visibleUntil);
  },

  clearPeriod(e) {
    e.preventDefault();

    if (!this.currentWrapper) return

    this.savePeriod("", "");
  },

  savePeriod(visibleFrom, visibleUntil) {
    const $actionButtons = this.getPopupActionButtons();

    $actionButtons.prop("disabled", true);
    this.showError(null);

    this.save(this.currentWrapper, { visible_from: visibleFrom, visible_until: visibleUntil })
      .then(() => {
        this.hidePopup();
      })
      .catch(() => {
        this.showError("save");
      })
      .always(() => {
        $actionButtons.prop("disabled", false);
      });
  },

  getPopupActionButtons() {
    return this.getPopup().find("button");
  },

  cancelPeriodEdit(e) {
    e.preventDefault();

    this.hidePopup();
  },

  handlePopupKeydown(e) {
    if (e.key === "Escape") {
      e.preventDefault();
      this.hidePopup();

      return
    }

    if (e.key === "Enter" && e.target.matches("input")) {
      this.acceptPeriodEdit(e);
    }
  },

  showError(type) {
    const $popup = this.getPopup();

    $popup.find(".js-content-block-visibility-period-order-error").prop("hidden", type !== "order");
    $popup.find(".js-content-block-visibility-period-save-error").prop("hidden", type !== "save");
  },

  hidePopup() {
    App.Studio.ContentBlocks.SimpleEditMode.EditPopup.hide(this.getPopup());
    this.currentWrapper = null;
  }
};
