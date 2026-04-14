(function() {
  "use strict";
  App.AutosubmitFilterInput = {

    updateLabelStyle: function($label) {
      $label.closest('ul').find('li.label-selected').each(function() {
        $(this).removeClass('label-selected');
      });

      $label.closest('li').addClass('label-selected');
    },

    updateParams: function($input) {
      var url = new URL(window.location.href);
      var paramName = $input.attr('name');
      var selectedValue = $input.val();

      url.searchParams.set(paramName, selectedValue);
      url.searchParams.delete('search');
      url.searchParams.delete('page');

      window.history.pushState('', '', url);
      window.location.href = url;
    },

    initialize: function() {
      $("body").on("click", ".js-autosubmit-filter-input", function() {
        var $label = $(this).closest('label');
        App.AutosubmitFilterInput.updateLabelStyle($label);
        App.AutosubmitFilterInput.updateParams($(this));
      });
    }

  };
}).call(this);
