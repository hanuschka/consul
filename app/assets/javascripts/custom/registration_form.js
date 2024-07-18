(function() {
  "use strict";
  App.RegistrationForm = {
    clearDependentFields: function() {
      if (event.target.id === "form_registered_address_city_id") {
        $("#form_registered_address_street_id").val("");
        $("#form_registered_address_id").val("");
      } else if (event.target.id === "form_registered_address_street_id") {
        $("#form_registered_address_id").val("");
      }
    },

    initialize: function() {
      $("body").on("change", ".js-registered-address-choose", function() {
        App.RegistrationForm.clearDependentFields();

        var selectedCityId = $("#form_registered_address_city_id").val();
        var selectedStreetId = $("#form_registered_address_street_id").val();
        var selectedAddressId = $("#form_registered_address_id").val();

        $.get("/registered_addresses/find", {
          selected_city_id: selectedCityId,
          selected_street_id: selectedStreetId,
          selected_address_id: selectedAddressId
        });
      })
    }
  };
}).call(this);
