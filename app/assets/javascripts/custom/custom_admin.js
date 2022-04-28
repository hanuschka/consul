(function() {
  "use strict";
  App.CustomAdmin = {

    // Street selector: start
    selectStreet: function(phaseName, streetId, streetName) {
      var checkboxId = 'projekt_' + phaseName + '_attributes_bam_street_ids_' + streetId
      $('#' + checkboxId).prop( "checked", true );

      var streetPill = "<div class='selected-projekt' data-street-id=" + streetId + ">" + streetName  + "<i class='fas fa-times js-deselect-street'></i></div>"
      var streetPillsDivId = "#projekt-phase-selected-streets-" + phaseName 
      $(streetPillsDivId).append(streetPill)
    },

    deselectStreet: function(streetId, phaseName, $streetPill) {
      var checkboxId = 'projekt_' + phaseName + '_attributes_bam_street_ids_' + streetId
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
    }
  }
}).call(this);
