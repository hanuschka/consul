(function() {
  "use strict";

  App.MapScreenshot = {
    takeScreenshot: function(mapContainerId, callback) {
      var element = document.getElementById(mapContainerId);

      if (!element) {
        console.error("Element not found:", mapContainerId);
        return;
      }

      var map_location_id_match = mapContainerId.match(/map_location_(\d+)/);
      if (!map_location_id_match) {
        console.error("MapLocationIdNotFound:", mapContainerId);
        return;
      }
      var map_location_id = map_location_id_match[1];

      var canvas = element.querySelector('canvas');

      if (canvas) {
        console.log("Canvas found, uploading screenshot from canvas.");
        App.MapScreenshot.uploadScreenShotFromCanvas(canvas, map_location_id, callback);
      } else {
        App.MapScreenshot.uploadScreenShotFromHtml(element, map_location_id, callback);
      }
    },

    uploadScreenShotFromCanvas: function(canvas, mapLocationId, callback) {
      canvas.toBlob(function(blob) {
        if (!blob) {
          console.error("Failed to generate blob from canvas");
          return;
        }

        App.MapScreenshot.uploadScreenshot(blob, mapLocationId, callback);
      }, "image/jpeg");
    },

    uploadScreenShotFromHtml: function(element, mapLocationId, callback) {
      html2canvas(element, { useCORS: true })
        .then(function(canvas) {
          canvas.toBlob(function(blob) {
            if (!blob) {
              console.error("Failed to generate blob from canvas");
              return;
            }

            App.MapScreenshot.uploadScreenshot(blob, mapLocationId, callback);
          }, "image/jpeg");
        }).catch(function(error) {
          console.error("html2canvas error:", error);
        });
    },

    uploadScreenshot: function(blob, mapLocationId, callback) {
      console.log("Blob:", blob);
      var formData = new FormData();
      formData.append("screenshot", blob, "screenshot.jpg");

      var csrfToken = document.querySelector('meta[name="csrf-token"]').getAttribute("content");

      var xhr = new XMLHttpRequest();
      xhr.open("POST", "/map_locations/" + mapLocationId + "/update_screenshot", true);
      xhr.setRequestHeader("X-CSRF-Token", csrfToken);

      xhr.onload = function() {
        if (xhr.status >= 200 && xhr.status < 300) {
          console.log("Screenshot uploaded successfully:", xhr.responseText);
          callback();
        } else {
          console.error("Error uploading screenshot:", xhr.status, xhr.responseText);
        }
      };

      xhr.onerror = function() {
        console.error("Request failed.");
      };
      xhr.send(formData);
    },

    initialize: function() {
      $("body").on("click", ".js-update-screenshot", function(event) {
        event.preventDefault();
        var mapContainerId = $(event.target).data("mapContainerId");
        App.MapScreenshot.takeScreenshot(mapContainerId, function() {
          window.location.href = event.target.href;
        });
      });
    }
  };
}).call(this);
