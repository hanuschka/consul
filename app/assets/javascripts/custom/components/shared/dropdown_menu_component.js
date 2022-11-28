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

      var dropdownOpenButton = e.currentTarget;

      if (dropdownOpenButton.nextElementSibling.classList.contains("dropdown-active") === true) {
        // Close the clicked dropdown
        dropdownOpenButton.parentElement.classList.remove("dropdown-open");
        dropdownOpenButton.nextElementSibling.classList.remove("dropdown-active");
      } else {
        // Close the opend dropdown
        this.closeDropdown();

        // add the open and active class(Opening the DropDown)
        dropdownOpenButton.parentElement.classList.add("dropdown-open");
        dropdownOpenButton.nextElementSibling.classList.add("dropdown-active");
      }
    },

    closeDropdown: function() {
      // remove the open and active class from other opened Dropdown (Closing the opend DropDown)
      document.querySelectorAll(".dropdown-container").forEach(function(container) {
        container.classList.remove("dropdown-open");
      });

      document.querySelectorAll(".dropdown-menu").forEach(function(menu) {
        menu.classList.remove("dropdown-active");
      });
    },

  };
}).call(this);
