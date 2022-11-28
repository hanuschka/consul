(function() {
  "use strict";
  App.DropdownMenuComponent = {
    initialize: function() {
      window.addEventListener("click", function(e) {
        if (e.target.closest(".dropdown-container") === null) {
          this.closeDropdown();
        }
      }.bind(this));

      $(document).on("click", ".dropdown-toggle", this.openDropdown.bind(this));
    },

    openDropdown: function(e) {
      e.preventDefault();

      var $dropdownElement = $(e.currentTarget.parentElement);

      if ($dropdownElement.hasClass("dropdown-open") === true) {
        $dropdownElement.removeClass("dropdown-open");
      } else {
        this.closeDropdown();
        $dropdownElement.addClass("dropdown-open");
      }
    },

    closeDropdown: function() {
      $(".dropdown-container.dropdown-open").removeClass("dropdown-open");
    },
  };
}).call(this);
