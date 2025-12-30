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

    handleKeydown: function(e) {
      var $container = $(e.currentTarget);
      var isOpen = $container.hasClass("dropdown-open");
      var isOnToggle = $(e.target).hasClass("js-dropdown-select-menu-toggle");
      var $items = $container.find(".js-dropdown-select-menu-item");
      var itemCount = $items.length;

      if (e.key === "Enter" || e.key === " ") {
        e.preventDefault();
        if (isOnToggle) {
          isOpen ? this.closeDropdown($container) : this.openDropdown($container);
        } else if (this.focusedIndex >= 0) {
          this.selectOptionByIndex($container, this.focusedIndex);
        }
        return;
      }

      if (e.key === "Escape") {
        e.preventDefault();
        this.closeDropdown($container);
        $container.find(".js-dropdown-select-menu-toggle").focus();
        return;
      }

      if (e.key === "ArrowDown" && !isOpen) {
        e.preventDefault();
        this.openDropdown($container);
        return;
      }

      if (!isOpen) return;

      if (e.key === "Tab") {
        if (e.shiftKey) {
          if (this.focusedIndex <= 0) {
            this.closeDropdown($container);
            $container.find(".js-dropdown-select-menu-toggle").focus();
          } else {
            e.preventDefault();
            this.focusedIndex--;
            this.updateFocusedItem($items);
          }
        } else {
          if (isOnToggle || this.focusedIndex < itemCount - 1) {
            e.preventDefault();
            this.focusedIndex++;
            this.updateFocusedItem($items);
            $container.find(".dropdown-select-menu--list").focus();
          } else {
            this.closeDropdown($container);
          }
        }
        return;
      }

      if (e.key === "ArrowDown") {
        e.preventDefault();
        this.focusedIndex = Math.min(this.focusedIndex + 1, itemCount - 1);
        this.updateFocusedItem($items);
      } else if (e.key === "ArrowUp") {
        e.preventDefault();
        this.focusedIndex = Math.max(this.focusedIndex - 1, 0);
        this.updateFocusedItem($items);
      } else if (e.key === "Home") {
        e.preventDefault();
        this.focusedIndex = 0;
        this.updateFocusedItem($items);
      } else if (e.key === "End") {
        e.preventDefault();
        this.focusedIndex = itemCount - 1;
        this.updateFocusedItem($items);
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
