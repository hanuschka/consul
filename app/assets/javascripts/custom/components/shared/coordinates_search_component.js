(function() {
  "use strict";
  App.CoordinatesSearchComponent = {
    update_selector: function() {
      var coordinatesParam = new URLSearchParams(window.location.search).get("coordinates")
      var selectedCoordinates = coordinatesParam ? coordinatesParam.split(',').map(Number) : [];

      var $text_field = $(".js-update-coordinates-selector");
      var $selector = $("#coordinates-selector select");
      $selector.empty();

      $.ajax({
        url: "/map_locations/get_coordinates",
        data: {
          address_query: $text_field.val()
        },
        type: "GET",
        success: function(data) {
          if(data.length > 0) {
            $selector.show();
            $selector.append($("<option></option>")
              .attr("value", "")
              .text("Bitte wählen..."));
            $.each(data, function(index, value) {
              var $option =  $selector.append($("<option></option>")
                .attr("value", value.coordinates)
                .attr("selected", (value.coordinates[0] == selectedCoordinates[0] && value.coordinates[1] == selectedCoordinates[1]))
                .text(value.address));
            });

          } else {
            $selector.hide();
          }
        }
      });
    },

    initialize: function() {
      var debounced_update_selector = App.Shared.debounce(this.update_selector, 1000);
      $("body").on("keyup", ".js-update-coordinates-selector", debounced_update_selector);
    }
  };

  document.addEventListener("turbolinks:load", function() {
    if ($(".js-update-coordinates-selector").length === 0) {
      return;
    }
    App.CoordinatesSearchComponent.update_selector();
  });
}).call(this);
