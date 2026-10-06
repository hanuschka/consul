(function() {
  "use strict";
  App.SidebarFilterComponent = {

    updateLabelStyle: function($label) {
      $label.closest('ul').find('li.selected-option').each( function() {
        $(this).removeClass('selected-option');
      })

      $label.closest('li').addClass('selected-option');
    },

    updateParams: function($label) {
      var url = new URL(window.location.href);
      var paramIdentifier = $label.closest('ul').data('identifier');
      var selectedOptions = $label.find('input:checked').val();
      if (selectedOptions == 'all') {
        url.searchParams.delete(paramIdentifier)
      } else {
        url.searchParams.set(paramIdentifier, selectedOptions)
      }
      Turbolinks.visit(url);
    },

    restoreCheckboxFocus: function() {
      try {
        var focusId = window.sessionStorage.getItem("sidebarCheckboxFilterFocus");
        window.sessionStorage.removeItem("sidebarCheckboxFilterFocus");

        if (!focusId) {
          return;
        }

        var element = document.getElementById(focusId);
        if (element && element.matches(".js-sidebar-checkbox-filter")) {
          element.focus();
        }
      } catch (e) {}
    },

    initialize: function() {
      App.SidebarFilterComponent.restoreCheckboxFocus();

      $("body").on("click", ".js-sidebar-radio-filter", function() {
        var $label = $(this).closest('label');
        App.SidebarFilterComponent.updateLabelStyle($label);
        App.SidebarFilterComponent.updateParams($label);
      });

      $("body").on("change", ".js-sidebar-checkbox-filter", function() {
        var $checkbox = $(this);
        var $list = $checkbox.closest('ul');
        var url = new URL(window.location.href);
        var paramIdentifier = $list.data('identifier');

        $checkbox.closest('li').toggleClass('selected-option', $checkbox.is(':checked'));

        url.searchParams.delete(paramIdentifier + '[]');
        $list.find('input:checked').each(function() {
          url.searchParams.append(paramIdentifier + '[]', $(this).val());
        });
        url.searchParams.delete('page');

        if (this.dataset.skipFocusRestore === "true") {
          delete this.dataset.skipFocusRestore;
        } else {
          try {
            window.sessionStorage.setItem("sidebarCheckboxFilterFocus", this.id);
          } catch (e) {}
        }

        window.location.href = url;
      });
    }

  };
}).call(this);
