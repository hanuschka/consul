(function() {
  "use strict";
  App.DropdownMenuComponent = {
    initialize: function() {
      window.addEventListener("click", function(e) {
        if (e.target.closest(".dropdown-container") === null) {
          this.closeDropdown();
        }
      }.bind(this));

      $(".js-dropdown-toggle").on("click", this.openDropdown.bind(this));
      $(".js-dropdown-item").on("click", this.selectOption.bind(this));
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

    selectOption: function(e) {
      this.closeDropdown();
      e.currentTarget.closest(".js-dropdown").querySelector(".dropdown-toggle").innerHTML = e.currentTarget.textContent;
    }
  };
}).call(this);
