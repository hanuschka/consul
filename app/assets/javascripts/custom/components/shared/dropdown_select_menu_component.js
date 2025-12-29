(function() {
  "use strict";
  App.DropdownSelectMenuComponent = {
    initialized: false,
    focusedIndex: -1,

    initialize: function() {
      if (this.initialized) {
        return;
      }

      window.addEventListener("click", function(e) {
        if (e.target.closest(".dropdown-select-container") === null) {
          this.closeAllDropdowns();
        }
      }.bind(this));

      $(document).on("click", ".js-dropdown-select-menu-toggle", this.toggleDropdown.bind(this));
      $(document).on("click", ".js-dropdown-select-menu-item", this.selectOption.bind(this));
      $(document).on("click", ".js-dropdown-select-menu-item a", this.selectOption.bind(this));
      $(document).on("keydown", ".js-dropdown-select-menu-toggle", this.handleToggleKeydown.bind(this));
      $(document).on("keydown", ".js-dropdown-select-menu", this.handleKeydown.bind(this));

      this.initialized = true;
    },

    toggleDropdown: function(e) {
      e.preventDefault();
      var $container = $(e.currentTarget.parentElement);

      if ($container.hasClass("dropdown-open")) {
        this.closeDropdown($container);
      } else {
        this.openDropdown($container);
      }
    },

    openDropdown: function($container) {
      this.closeAllDropdowns();
      $container.addClass("dropdown-open");
      $container.find(".js-dropdown-select-menu-toggle").attr("aria-expanded", "true");
      this.focusedIndex = -1;
    },

    closeDropdown: function($container) {
      $container.removeClass("dropdown-open");
      $container.find(".js-dropdown-select-menu-toggle").attr("aria-expanded", "false");
      $container.find(".js-dropdown-select-menu-item").removeClass("dropdown-select-menu-item--focused");
      this.focusedIndex = -1;
    },

    closeAllDropdowns: function() {
      var self = this;
      $(".dropdown-select-container.dropdown-open").each(function() {
        self.closeDropdown($(this));
      });
    },

    handleToggleKeydown: function(e) {
      var $container = $(e.currentTarget).closest(".js-dropdown-select-menu");
      var isOpen = $container.hasClass("dropdown-open");

      if (e.key === "Enter" || e.key === " ") {
        e.preventDefault();
        if (isOpen) {
          this.closeDropdown($container);
        } else {
          this.openDropdown($container);
        }
      } else if (e.key === "ArrowDown" && !isOpen) {
        e.preventDefault();
        this.openDropdown($container);
      } else if (e.key === "Escape" && isOpen) {
        e.preventDefault();
        this.closeDropdown($container);
        $container.find(".js-dropdown-select-menu-toggle").focus();
      }
    },

    handleKeydown: function(e) {
      var $container = $(e.currentTarget);
      if (!$container.hasClass("dropdown-open")) {
        return;
      }

      var $items = $container.find(".js-dropdown-select-menu-item");
      var itemCount = $items.length;

      switch (e.key) {
        case "ArrowDown":
          e.preventDefault();
          this.focusedIndex = Math.min(this.focusedIndex + 1, itemCount - 1);
          this.updateFocusedItem($items);
          break;
        case "ArrowUp":
          e.preventDefault();
          this.focusedIndex = Math.max(this.focusedIndex - 1, 0);
          this.updateFocusedItem($items);
          break;
        case "Home":
          e.preventDefault();
          this.focusedIndex = 0;
          this.updateFocusedItem($items);
          break;
        case "End":
          e.preventDefault();
          this.focusedIndex = itemCount - 1;
          this.updateFocusedItem($items);
          break;
        case "Enter":
        case " ":
          e.preventDefault();
          if (this.focusedIndex >= 0) {
            this.selectOptionByIndex($container, this.focusedIndex);
          }
          break;
        case "Escape":
          e.preventDefault();
          this.closeDropdown($container);
          $container.find(".js-dropdown-select-menu-toggle").focus();
          break;
        case "Tab":
          this.closeDropdown($container);
          break;
      }
    },

    updateFocusedItem: function($items) {
      $items.removeClass("dropdown-select-menu-item--focused");
      if (this.focusedIndex >= 0) {
        $items.eq(this.focusedIndex).addClass("dropdown-select-menu-item--focused");
      }
    },

    selectOptionByIndex: function($container, index) {
      var $item = $container.find(".js-dropdown-select-menu-item").eq(index);
      var $link = $item.find("a");

      if ($link.length > 0) {
        $link[0].click();
      } else {
        var text = $item.text().trim();
        $container.find(".js-dropdown-select-menu-toggle").text(text);
      }

      this.closeDropdown($container);
      $container.find(".js-dropdown-select-menu-toggle").focus();
    },

    selectOption: function(e) {
      var $container = $(e.currentTarget).closest(".js-dropdown-select-menu");
      var text = $(e.currentTarget).text().trim();

      $container.find(".js-dropdown-select-menu-toggle").text(text);
      this.closeDropdown($container);
    }
  };
}).call(this);
