(function() {
  "use strict";

  const SELECTORS = {
    root: ".js-account-username",
    editButton: ".js-account-username-edit-button",
    form: ".js-account-username-form",
    input: ".js-account-username-input",
    cancel: ".js-account-username-cancel",
    save: ".js-account-username-save",
    name: ".js-account-username-name",
    error: ".js-account-username-error"
  };

  const EDITING_CLASS = "-editing";
  const INVALID_CLASS = "is-invalid-input";

  App.AccountUsernameEditComponent = {
    initialize() {
      const $document = $(document);

      $document.on("click", SELECTORS.editButton, this.handleEdit.bind(this));
      $document.on("click", SELECTORS.cancel, this.handleCancel.bind(this));
      $document.on("submit", SELECTORS.form, this.handleSubmit.bind(this));
      $document.on("keydown", SELECTORS.input, this.handleKeydown.bind(this));
    },

    handleEdit(event) {
      const root = event.target.closest(SELECTORS.root);
      const input = root.querySelector(SELECTORS.input);

      this.syncInputWithName(root);
      this.clearError(root);
      root.classList.add(EDITING_CLASS);

      input.focus();
      input.select();
    },

    handleCancel(event) {
      this.closeEditing(event.target.closest(SELECTORS.root));
    },

    handleKeydown(event) {
      if (event.key !== "Escape") return;

      this.closeEditing(event.target.closest(SELECTORS.root));
    },

    handleSubmit(event) {
      event.preventDefault();

      const root = event.target.closest(SELECTORS.root);
      const form = event.target.closest(SELECTORS.form);
      const username = root.querySelector(SELECTORS.input).value.trim();
      const url = form.getAttribute("data-update-url");

      if (username.length === 0) {
        this.showError(root, "Bitte gib einen Benutzernamen ein.");

        return;
      }

      this.setLoading(root, true);

      App.Ajax
        .patch(url, { user: { username: username } })
        .done(this.handleSuccess.bind(this, root))
        .fail(this.handleError.bind(this, root))
        .always(this.setLoading.bind(this, root, false));
    },

    handleSuccess(root, response) {
      if (response && response.name) {
        root.querySelector(SELECTORS.name).textContent = response.name;
      }

      this.clearError(root);
      root.classList.remove(EDITING_CLASS);
    },

    handleError(root, xhr) {
      const response = xhr.responseJSON;
      let message = "Der Benutzername konnte nicht gespeichert werden.";

      if (response && response.errors && response.errors.length > 0) {
        message = response.errors.join(" ");
      }

      this.showError(root, message);
    },

    closeEditing(root) {
      this.syncInputWithName(root);
      this.clearError(root);
      root.classList.remove(EDITING_CLASS);
    },

    syncInputWithName(root) {
      const name = root.querySelector(SELECTORS.name).textContent.trim();
      root.querySelector(SELECTORS.input).value = name;
    },

    showError(root, message) {
      const errorElement = root.querySelector(SELECTORS.error);

      root.querySelector(SELECTORS.input).classList.add(INVALID_CLASS);
      errorElement.textContent = message;
      errorElement.hidden = false;
    },

    clearError(root) {
      const errorElement = root.querySelector(SELECTORS.error);

      root.querySelector(SELECTORS.input).classList.remove(INVALID_CLASS);
      errorElement.textContent = "";
      errorElement.hidden = true;
    },

    setLoading(root, isLoading) {
      root.querySelector(SELECTORS.save).disabled = isLoading;
      root.querySelector(SELECTORS.cancel).disabled = isLoading;
    }
  };
}).call(this);
