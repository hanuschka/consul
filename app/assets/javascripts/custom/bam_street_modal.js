(function() {
  "use strict";
  App.BamStreetModal = {

    showModal: function() {
      var isStreetSelected = $('#selectBamStreetModal').data('show-modal');

      if ( isStreetSelected == true && App.Cookies.getCookie('consul_bam_street_modal_seen') != 'true' ) {
        $('#selectBamStreetModal').foundation('open');
      }

    },

    hideModal: function() {
      App.Cookies.saveCookie('consul_bam_street_modal_seen', true, 1)
    },

    initialize: function() {
      App.BamStreetModal.showModal();

      $("body").on("closed.zf.reveal", "#selectBamStreetModal", function() {
        App.BamStreetModal.hideModal();
      })
    }
  }
}).call(this);
