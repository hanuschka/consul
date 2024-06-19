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

    initialize: function() {
      $("body").on("click", ".js-sidebar-radio-filter", function() {
        var $label = $(this).closest('label');
        App.SidebarFilterComponent.updateLabelStyle($label);
        App.SidebarFilterComponent.updateParams($label);
      });
    }

  };
}).call(this);
