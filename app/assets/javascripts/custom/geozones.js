(function() {
  "use strict";
  App.Geozones = {

    updateLabelStyle: function($label) {
      $label.closest('ul').find('li.label-selected').each( function() {
        $(this).removeClass('label-selected');
      })      

      $label.closest('li').addClass('label-selected')
    },

    updateGeozoneAffiliationParam: function($label) {
      var url = new URL(window.location.href);
      var selection = $('input[name="geozone_affiliation"]:checked').val();
      url.searchParams.set('geozone_affiliation', selection)
      window.history.pushState('', '', url)
    },

    updateGeozoneRestrictionParam: function($label) {
      var url = new URL(window.location.href);
      var selection = $('input[name="geozone_restriction"]:checked').val();
      url.searchParams.set('geozone_restriction', selection)
      window.history.pushState('', '', url)
    },

    updateGeozonesParams: function($checkbox) {
      var url = new URL(window.location.href);
      var selected_geozones = [];
      var geozone_filter = $checkbox.closest("ul").attr('id')

      $checkbox.closest("ul").find("input:checkbox:checked").each( function() {
        selected_geozones.push($(this).val())
      });

      if (selected_geozones.length) {
        url.searchParams.set(geozone_filter, selected_geozones.join(','))
      } else {
        url.searchParams.delete(geozone_filter)
      };

      window.history.pushState('', '', url);
    },

    resetGeozoneAffiliationFilter: function() {
      var url = new URL(window.location.href);

      $('#affiliation-filter input').each(
        function() {
          $(this).prop('checked', false);
        }
      )

      $('#affiliation-filter li').each(
        function() {
          $(this).removeClass('label-selected');
        }
      )

      url.searchParams.delete('affiliated-geozones');

      url.searchParams.set('geozone_affiliation', 'no_affiliation');
      $('#affiliation-filter li').first().addClass('label-selected');
      $('#affiliation-filter li input[type="radio"]').first().prop("checked", true);

      window.history.pushState('', '', url)
      //window.location.href = url;
    },

    resetGeozoneRestrictionFilter: function() {
      var url = new URL(window.location.href);

      $('#restriction-filter input').each(
        function() {
          $(this).prop('checked', false);
        }
      )

      $('#restriction-filter li').each(
        function() {
          $(this).removeClass('label-selected');
        }
      )

      url.searchParams.delete('restricted-geozones');

      url.searchParams.set('geozone_restriction', 'no_restriction');
      $('#restriction-filter li').first().addClass('label-selected');
      $('#restriction-filter li input[type="radio"]').first().prop("checked", true);

      window.history.pushState('', '', url)
      //window.location.href = url;
    },

    initialize: function() {

      $("body").on("click", ".js-filter-geozone-affiliation", function() {
        var $label = $(this).closest('label');
        App.Geozones.updateLabelStyle($label);
        App.Geozones.updateGeozoneAffiliationParam($label);
      });

      $("body").on("click", ".js-filter-geozone-restriction", function() {
        var $label = $(this).closest('label');
        App.Geozones.updateLabelStyle($label);
        App.Geozones.updateGeozoneRestrictionParam($label);
      });

      $("body").on("click", ".js-filter-geozones", function() {
        var $checkbox = $(this)
        App.Geozones.updateGeozonesParams($checkbox);
        $checkbox.closest('li').toggleClass('label-selected')
      });

      $("body").on("click", ".js-apply-geozone-filter", function() {
        var url = new URL(window.location.href);
        window.location.href = url;
      });

      $("body").on("click", ".js-show-all-geozones", function(event) {
        event.preventDefault();
        $(this).parent().siblings('li').each(function() { 
          $(this).removeClass('hide');
        })
        $(this).addClass('hide');
      });

      $("body").on("click", ".js-reset-affiliation-filter", function() {
        App.Geozones.resetGeozoneAffiliationFilter();
      });

      $("body").on("click", ".js-reset-restriction-filter", function() {
        App.Geozones.resetGeozoneRestrictionFilter();
      });

    }
  };
}).call(this);
