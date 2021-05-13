(function() {
  "use strict";
  App.Geozones = {

    updateLabelStyle: function($label) {
      $('#filter-geozones label').each( function() {
        $(this).removeClass('label-selected');
      })      

      $label.addClass('label-selected')
    },

    updateGeozoneParam: function($label) {
      var url = new URL(window.location.href);
      var selection = $('input[name="geozone"]:checked').val();
      url.searchParams.set('geozone', selection)
      window.history.pushState('', '', url)
    },

    initialize: function() {

      $("body").on("click", ".js-filter-geozone", function() {
        var $label = $(this).closest('label');
        App.Geozones.updateLabelStyle($label);
        App.Geozones.updateGeozoneParam($label);
      });

      $("body").on("click", ".js-apply-geozone-filter", function() {
        var url = new URL(window.location.href);
        window.location.href = url;
      });

      $("body").on("click", ".js-reset-geozone-filter", function() {
        var url = new URL(window.location.href);

        if (url.searchParams.get('geozone')) {
          url.searchParams.delete('geozone');
        }

        window.location.href = url;
      });

    }
  };
}).call(this);
