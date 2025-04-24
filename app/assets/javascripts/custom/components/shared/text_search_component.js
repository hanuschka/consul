(function() {
  "use strict";

  App.TextSearchFormComponent = {
    initialize: function() {
      var elements = document.querySelectorAll('.js-text-search-form');

      elements.forEach(element => {
        this.initializeFor(element)
      })
    },

    initializeFor: function(element) {
      var searchInput = this.searchInput(element);

      if (searchInput) {
        this.setupEventListeners(element);
        this.updateButtonVisibility(element);
      }
    },

    searchInput: function() {
      return document.querySelector('.js-search-input');
    },

    searchButton: function() {
      return document.querySelector('.js-search-button');
    },

    resetButton: function() {
      return document.querySelector('.js-text-search-form-reset-button');
    },

    setupEventListeners: function(rootElement) {
      var searchInput = this.searchInput(rootElement)

      searchInput.addEventListener('input', function() {
        this.updateButtonVisibility(rootElement);
      }.bind(this));

      this.resetButton(rootElement).addEventListener('click', function () {
        console.log("resetButton click")
        this.handleReset(rootElement);
      }.bind(this));
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

