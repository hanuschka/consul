// Eye toggle and visibility period of a content block. Both save immediately
// through the block's regular update URL; the server answers with the new
// state (including whether citizens see the block right now), which is then
// re-rendered into the toolbar and the hint.
//
// The period form lives in an <inline-popup> around each calendar button, so
// outside clicks and Escape close it natively. Every block has its own copy of
// the form, which is why all lookups below are scoped to one popup.
App.Studio.ContentBlocks.Visibility = {
  initialize() {
    const $document = $(document);

    $document.on("click", ".js-content-block-toggle-visibility", this.handleToggleClick.bind(this));
    $document.on("inline-popup:open", ".js-content-block-visibility-period-popup", this.handlePeriodPopupOpen.bind(this));
    $document.on("inline-popup:close", ".js-content-block-visibility-period-popup", this.handlePeriodPopupClose.bind(this));
    $document.on("click", ".js-content-block-accept-visibility-period", this.acceptPeriodEdit.bind(this));
    $document.on("click", ".js-content-block-clear-visibility-period", this.clearPeriod.bind(this));
    $document.on("keydown", ".js-content-block-visibility-period-popup input", this.handlePeriodInputKeydown.bind(this));
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
    return this
      .requestUpdate(wrapper, data)
      .then((response) => {
        this.applySavedState(wrapper, response);
      });
  },

  requestUpdate(wrapper, data) {
    return App.Ajax.request({
      url: App.Studio.ContentBlocks.Crud.getUpdateUrl(wrapper),
      type: "PATCH",
      dataType: "json",
      data: data
    });
  },

  applySavedState(wrapper, response) {
    this.applyState(wrapper, this.fromServerState(response.visibility));
    App.Studio.ContentBlocks.DomHelpers.showBlockStatus(wrapper, "saved");
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

  getPeriodPopup(element) {
    return element.closest(".js-content-block-visibility-period-popup");
  },

  getFromInput(popup) {
    return popup.querySelector(".js-content-block-visible-from-input");
  },

  getUntilInput(popup) {
    return popup.querySelector(".js-content-block-visible-until-input");
  },

  getPopupActionButtons(popup) {
    return popup.querySelectorAll(".js-content-block-visibility-period-actions button");
  },

  handlePeriodPopupOpen(e) {
    const popup = e.currentTarget;
    const wrapper = App.Studio.ContentBlocks.DomHelpers.getParentContentBlockWrapper(popup);

    if (!this.isPersisted(wrapper)) {
      popup.close();

      return
    }

    const visibility = this.readFromElement(wrapper);

    this.getFromInput(popup).value = visibility.visibleFrom;
    this.getUntilInput(popup).value = visibility.visibleUntil;
    popup.querySelector(".js-content-block-visibility-period-hidden-note").hidden = visibility.visible;
    this.showError(popup, null);
    this.suppressTooltip(popup);

    this.getFromInput(popup).focus();
  },

  handlePeriodPopupClose(e) {
    this.restoreTooltip(e.currentTarget);
  },

  // The calendar button's rich-tooltip wraps the popup, so without this it
  // would open over the form while the pointer rests on it.
  suppressTooltip(popup) {
    const tooltip = popup.closest("rich-tooltip");

    if (!tooltip) return

    tooltip.setAttribute("disabled", "");

    if (tooltip.tooltipBody) tooltip.hide();
  },

  restoreTooltip(popup) {
    const tooltip = popup.closest("rich-tooltip");

    if (!tooltip) return

    tooltip.removeAttribute("disabled");
  },

  handlePeriodInputKeydown(e) {
    if (e.key !== "Enter") return

    this.acceptPeriodEdit(e);
  },

  acceptPeriodEdit(e) {
    e.preventDefault();

    const popup = this.getPeriodPopup(e.currentTarget);
    const visibleFrom = this.getFromInput(popup).value;
    const visibleUntil = this.getUntilInput(popup).value;

    // Same-format local timestamps compare correctly as strings.
    if (visibleFrom && visibleUntil && visibleUntil < visibleFrom) {
      this.showError(popup, "order");

      return
    }

    this.savePeriod(popup, visibleFrom, visibleUntil);
  },

  clearPeriod(e) {
    e.preventDefault();

    this.savePeriod(this.getPeriodPopup(e.currentTarget), "", "");
  },

  // The popup is closed before the new state re-renders the toolbar, since
  // that re-render replaces the popup element itself.
  savePeriod(popup, visibleFrom, visibleUntil) {
    const wrapper = App.Studio.ContentBlocks.DomHelpers.getParentContentBlockWrapper(popup);
    const actionButtons = this.getPopupActionButtons(popup);

    actionButtons.forEach((button) => { button.disabled = true; });
    this.showError(popup, null);

    this
      .requestUpdate(wrapper, { visible_from: visibleFrom, visible_until: visibleUntil })
      .then((response) => {
        popup.close();
        this.applySavedState(wrapper, response);
      })
      .catch(() => {
        actionButtons.forEach((button) => { button.disabled = false; });
        this.showError(popup, "save");
      });
  },

  showError(popup, type) {
    popup.querySelector(".js-content-block-visibility-period-order-error").hidden = type !== "order";
    popup.querySelector(".js-content-block-visibility-period-save-error").hidden = type !== "save";
  }
};
