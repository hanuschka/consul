(function() {
  "use strict";
  App.CustomAdmin = {

    // Street selector: start
    selectStreet: function(phaseName, streetId, streetName) {
      var checkboxId;

      if (phaseName == 'voting_phase') {
        checkboxId = 'poll_' + phaseName + '_attributes_bam_street_ids_' + streetId
      } else {
        checkboxId = 'projekt_' + phaseName + '_attributes_bam_street_ids_' + streetId
      }

      $('#' + checkboxId).prop( "checked", true );

      var streetPill = "<div class='selected-projekt' data-street-id=" + streetId + ">" + streetName  + "<i class='fas fa-times js-deselect-street'></i></div>"
      var streetPillsDivId = "#projekt-phase-selected-streets-" + phaseName 
      $(streetPillsDivId).append(streetPill)
    },

    deselectStreet: function(streetId, phaseName, $streetPill) {
      var checkboxId;

      if (phaseName == 'voting_phase') {
        checkboxId = 'poll_' + phaseName + '_attributes_bam_street_ids_' + streetId
      } else {
        checkboxId = 'projekt_' + phaseName + '_attributes_bam_street_ids_' + streetId
      }


      $('#' + checkboxId).prop( "checked", false);
      $streetPill.remove();
    },
    // Street selector: end

    initialize: function() {
      $("body").on("change", ".js-select-street", function() { // select street
        var streetId = this.value;
        var streetName = $(this).find('option:selected').text();
        var phaseName = $(event.target).closest('.projekt-phase-street-selector').data('phase-name');
        App.CustomAdmin.selectStreet(phaseName, streetId, streetName);
      })

      $("body").on("click", ".js-deselect-street", function() {
        var $streetPill = $(this).closest('.selected-projekt');
        var streetId = $streetPill.data('street-id');
        var phaseName = $(this).closest('.projekt-phase-street-selector').data('phase-name');
        App.CustomAdmin.deselectStreet(streetId, phaseName, $streetPill);
      })

      $("body").on("click", ".js-map-layer-base-checkbox", function() {
        var $base_checkbox = $(this)
        var $show_by_default_chechbox = $base_checkbox.closest('.checkboxes').find('#map_layer_show_by_default')

        if ( $base_checkbox.is(':checked') ) {
          $show_by_default_chechbox.prop('checked', false);
          $show_by_default_chechbox.attr("disabled", true);
        } else {
          $show_by_default_chechbox.removeAttr("disabled");
        }
      })

      $("body").on("click", ".js-map-protocol", function() {
        var $selectedRadioButton = $(this)
        var $transparentCheckbox = $selectedRadioButton.closest('.map-layer-form').find('#map_layer_transparent')
        var $layerNamesInput = $selectedRadioButton.closest('.map-layer-form').find('#map_layer_layer_names')

        if ( $selectedRadioButton.val() == 'regular' ) {
          $transparentCheckbox.prop("checked", false);
          $transparentCheckbox.attr("disabled", true);
          $layerNamesInput.attr("disabled", true);
  
        } else if ( $selectedRadioButton.val() == 'wms' ) {
          $transparentCheckbox.removeAttr("disabled");
          $layerNamesInput.removeAttr("disabled");
        }
      })

      $("body").on("click", ".js-toggle-availability-of-verification-settings button", function() {
        $('.js-verification-settings button').prop('disabled', $(this).attr('aria-pressed') == 'true')
      })

      $(document).on("click", ".js-admin-edit-projekt-event", function(e) {
        App.HTMLEditor.initialize();
      })
    }
  };
}).call(this);
