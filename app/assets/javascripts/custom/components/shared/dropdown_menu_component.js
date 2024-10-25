(function() {
  "use strict";
  App.DropdownMenuComponent = {
    initialized: false,

    initialize: function() {
      if (this.initialized) {
        return;
      }
      this.closeDropdownGlobaly = this.closeDropdownGlobaly.bind(this);

      $(document).on("click", ".js-dropdown-menu-toggle", this.openDropdown.bind(this));
      $(document).on("click", ".js-dropdown-menu-item", this.closeDropdown.bind(this));

      this.initialized = true;
    },

    closeDropdownGlobaly: function(e) {
      if (e.target.closest(".dropdown-menu-container") === null) {
        this.closeDropdown();
      }
    },

    openDropdown: function(e) {
      e.preventDefault();

      document.removeEventListener("click", this.closeDropdownGlobaly);
      document.addEventListener("click", this.closeDropdownGlobaly);

      var $dropdownElement = $(e.currentTarget.parentElement);

      if ($dropdownElement.hasClass("dropdown-open") === true) {
        $dropdownElement.removeClass("dropdown-open");
      } else {
        $dropdownElement.addClass("dropdown-open");
      }
    },

    closeDropdown: function() {
      document.removeEventListener("click", this.closeDropdownGlobaly);

      $(".dropdown-menu-container.dropdown-open").removeClass("dropdown-open");
    },
  };
}).call(this);
