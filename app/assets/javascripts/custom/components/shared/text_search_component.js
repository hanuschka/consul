(function() {
  "use strict";

  App.TextSearchFormComponent = {
    initialize: function() {
      var elements = document.querySelectorAll('.js-text-search-form');

      this.setupEventListeners();

      elements.forEach(element => {
        this.initializeFor(element)
      })
    },

    initializeFor: function(element) {
      var searchInput = this.searchInput(element);

      if (searchInput) {
        this.updateButtonVisibility(element);
      }
    },

    searchInput: function(rootElement) {
      return rootElement.querySelector('.js-text-search-form-search-input');
    },

    resetButton: function(rootElement) {
      return rootElement.querySelector('.js-text-search-form-reset-button');
    },

    setupEventListeners: function() {
      $(document).on(
        'input',
        ".js-text-search-form-search-input",
        function(e) {
          var rootElement = e.target.closest('.js-text-search-form')

          this.updateButtonVisibility(rootElement)
        }.bind(this)
      )

      $(document).on(
        'click',
        ".js-text-search-form-reset-button",
        function(e) {
          var rootElement = e.target.closest('.js-text-search-form')

          this.handleReset(rootElement)
        }.bind(this)
      )

      $(document).on(
        'click',
        ".js-search-button",
        function(e) {
          var rootElement = e.target.closest('.js-text-search-form')

          if (!rootElement) return
          if (rootElement.tagName !== "FORM") {
            e.preventDefault()
            var input = this.searchInput(rootElement)
            if (input) {
              input.dispatchEvent(new Event('input', { bubbles: true }))
            }
          }
        }.bind(this)
      )
    },

    updateButtonVisibility: function(rootElement) {
      var hasValue = this.searchInput(rootElement).value.trim().length > 0;
      var resetBtn = rootElement.querySelector(".js-text-search-form-reset-button");

      rootElement.classList.toggle("-active", hasValue);

      if (resetBtn) {
        resetBtn.disabled = !hasValue;
      }
    },

    handleReset: function(rootElement) {
      var searchInput = this.searchInput(rootElement);

      searchInput.value = '';
      this.updateButtonVisibility(rootElement);
      searchInput.focus();
      searchInput.dispatchEvent(new Event('input', { bubbles: true }));

      if (rootElement.dataset.disableResetButtonSubmit !== "true") {
        rootElement.requestSubmit()
      }
    }
  };
}).call(this);

