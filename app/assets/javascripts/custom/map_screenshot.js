(function() {
  "use strict";

  const READY_TIMEOUT_MS = 8000;

  App.MapScreenshot = {
    takeScreenshot(mapContainerId, callback) {
      const element = document.getElementById(mapContainerId);

      if (!element) {
        console.error("Map container not found:", mapContainerId);
        callback();
        return;
      }

      const mapLocationId = element.dataset.mapLocationId;

      App.MapScreenshot
        .waitForMapIdle(element)
        .then(() => App.MapScreenshot.captureBlob(element))
        .then((blob) => App.MapScreenshot.uploadScreenshot(blob, mapLocationId))
        .then(() => callback())
        .catch((error) => {
          console.error("Map screenshot failed:", error);
          callback();
        });
    },

    waitForMapIdle(element) {
      const mapInstance = App.MapScreenshot.findMapInstance(element);

      if (!mapInstance) return Promise.resolve();
      if (typeof mapInstance.whenIdle !== "function") return Promise.resolve();

      const idlePromise = mapInstance.whenIdle();
      const timeoutPromise = new Promise((resolve) => {
        setTimeout(resolve, READY_TIMEOUT_MS);
      });

      return Promise.race([idlePromise, timeoutPromise]);
    },

    findMapInstance(element) {
      const maps = (App.Map && App.Map.maps) || [];

      for (let i = 0; i < maps.length; i++) {
        if (maps[i].element === element) return maps[i];
      }

      return null;
    },

    captureBlob(element) {
      const canvas = element.querySelector("canvas");

      if (canvas) return App.MapScreenshot.canvasToBlobPromise(canvas);

      return App.MapScreenshot.htmlToCanvasPromise(element);
    },

    canvasToBlobPromise(canvas) {
      return new Promise((resolve, reject) => {
        try {
          canvas.toBlob((blob) => {
            if (blob) {
              resolve(blob);
            } else {
              reject(new Error("Canvas toBlob returned null"));
            }
          }, "image/jpeg", 0.85);
        } catch (e) {
          reject(e);
        }
      });
    },

    htmlToCanvasPromise(element) {
      if (typeof html2canvas !== "function") {
        return Promise.reject(new Error("html2canvas is not loaded"));
      }

      return html2canvas(element, {
        useCORS: true,
        allowTaint: false,
        logging: false
      }).then((canvas) => App.MapScreenshot.canvasToBlobPromise(canvas));
    },

    uploadScreenshot(blob, mapLocationId) {
      return new Promise((resolve, reject) => {
        const formData = new FormData();
        formData.append("screenshot", blob, "screenshot.jpg");

        const csrfMeta = document.querySelector('meta[name="csrf-token"]');
        const csrfToken = csrfMeta ? csrfMeta.getAttribute("content") : "";

        const xhr = new XMLHttpRequest();
        xhr.open("POST", "/map_locations/" + mapLocationId + "/update_screenshot", true);
        xhr.setRequestHeader("X-CSRF-Token", csrfToken);

        xhr.onload = function() {
          if (xhr.status >= 200 && xhr.status < 300) {
            resolve(xhr.responseText);
          } else {
            reject(new Error("Upload failed: " + xhr.status + " " + xhr.responseText));
          }
        };

        xhr.onerror = function() {
          reject(new Error("Upload request failed"));
        };

        xhr.send(formData);
      });
    },

    handleClick(event) {
      event.preventDefault();
      const mapContainerId = $(event.currentTarget).data("mapContainerId");
      const href = event.currentTarget.href;

      App.MapScreenshot.takeScreenshot(mapContainerId, () => {
        window.location.href = href;
      });
    },

    initialize() {
      $("body").on("click", ".js-update-screenshot", App.MapScreenshot.handleClick);
    }
  };
}).call(this);
