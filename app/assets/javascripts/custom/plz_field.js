(function() {
  "use strict";

  App.PlzField = {
    toggle_plz_field: function($checkbox) {

      var $plzField = $('input[id$="_plz"]')

      if ( $checkbox.is(":checked") ) {
        $plzField.prop( "disabled", false );
      } else {
        $plzField.prop( "disabled", true );
        $plzField.val( "" );
      }
    },

    initialize: function() {
      $("body .js-toggle-plz-field").change( function() {
        var $checkbox = $(this)
        App.PlzField.toggle_plz_field($checkbox);
      });
    }
  };
}).call(this);
