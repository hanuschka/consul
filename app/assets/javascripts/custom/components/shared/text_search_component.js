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

    searchInput: function() {
      return document.querySelector('.js-text-search-form-search-input');
    },

    resetButton: function() {
      return document.querySelector('.js-text-search-form-reset-button');
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
    },

    updateButtonVisibility: function(rootElement) {

      var hasValue = this.searchInput(rootElement).value.trim().length > 0;

      rootElement.classList.toggle("-active", hasValue)
    },

    handleReset: function(rootElement) {
      var searchInput = this.searchInput(rootElement);

      searchInput.value = '';
      this.updateButtonVisibility(rootElement);
      searchInput.focus();

      if (rootElement.dataset.disableResetButtonSubmit !== "true") {
        rootElement.requestSubmit()
      }
    }
  };
}).call(this);

