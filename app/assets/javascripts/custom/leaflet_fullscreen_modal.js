if (window.L) {
// Custom Leaflet control for fullscreen modal functionality
  window.L.Control.FullscreenModal = L.Control.extend({
    options: {
      position: 'topright'
    },

    initialize: function(options) {
      window.L.Control.prototype.initialize.call(this, options);
      this.originalElement = options.element;
      this.modalId = 'leaflet-fullscreen-modal-' + Date.now();
      this.modalMapElement = null;
      this.isInModal = false;
    },

    onAdd: function(map) {
      this.map = map;

      // Create control container
      var container = L.DomUtil.create('div', 'leaflet-control-fullscreen leaflet-bar leaflet-control');

      // Create button
      var button = L.DomUtil.create('button', 'leaflet-control-fullscreen-button', container);
      button.href = '#';
      button.title = 'Vollbild-Modus';
      button.innerHTML = '<i class="fas fa-expand"></i>';

      // Prevent map events when clicking button
      L.DomEvent.disableClickPropagation(button);
      L.DomEvent.disableScrollPropagation(button);

      // Add click handler
      L.DomEvent.on(button, 'click', this.openModal, this);

      return container;
    },

    openModal: function(e) {
      L.DomEvent.preventDefault(e);

      if (this.isInModal) return;

      this.createModalStructure();
      this.initializeModalMap();
      this.showFoundationModal();

      this.isInModal = true;
    },

    createModalStructure: function() {
      var modalHtml = `
        <div class="reveal map-modal" id="${this.modalId}" data-reveal data-close-on-click="true" data-close-on-esc="true">
          <button class="map-modal--close-button" data-close aria-label="Modal schließen" type="button">
            <span aria-hidden="true">&times;</span>
          </button>
          <div id="${this.modalId}-map-container" style="width: 100%; height: 100%;"></div>
        </div>
      `;

      document.body.insertAdjacentHTML('beforeend', modalHtml);

      var modal = document.getElementById(this.modalId);
      var self = this;

      // Set up event listeners
      $(modal).on('closed.zf.reveal', function() {
        self.closeModal();
      });

      var closeButton = modal.querySelector('.map-modal--close-button');
      if (closeButton) {
        closeButton.addEventListener('click', () => {
          self.closeModal();
        });
      }

      // ESC key handler
      this.escHandler = function(e) {
        if (e.key === 'Escape' && self.isInModal) {
          self.closeModal();
          document.removeEventListener('keydown', self.escHandler);
        }
      };
      document.addEventListener('keydown', this.escHandler);
    },

    initializeModalMap: function() {
      var modalContainer = document.getElementById(this.modalId + '-map-container');

      // Copy all data attributes from original element
      this.copyDataAttributes(this.originalElement, modalContainer);

      // Mark as modal map
      modalContainer.setAttribute('data-modal-map', 'true');

      // Get current map state
      var center = this.map.getCenter();
      var zoom = this.map.getZoom();

      // Override center and zoom with current values
      modalContainer.setAttribute('data-map-center-latitude', center.lat);
      modalContainer.setAttribute('data-map-center-longitude', center.lng);
      modalContainer.setAttribute('data-map-zoom', zoom);

      // Set unique ID for modal map
      modalContainer.id = this.modalId + '-map';

      // Store reference for cleanup
      this.modalMapElement = modalContainer;

      // Initialize new Leaflet map in modal
      App.Map.initializeMapFor(modalContainer);

      // Find the newly created map and sync view with proper timing
      setTimeout(() => {
        var modalMapInstance = App.Map.instances[App.Map.instances.length - 1];
        if (modalMapInstance) {
          var modalMap = modalMapInstance.map;
          // Ensure map container is properly sized
          modalMap.invalidateSize();
          // Set the view to match original map
          modalMap.setView(center, zoom);
          // Force another resize after view is set
          setTimeout(() => {
            modalMap.invalidateSize(true);
          }, 50);
        }
      }, 100);
    },

    copyDataAttributes: function(sourceElement, targetElement) {
      // Copy all data attributes using jQuery
      var data = $(sourceElement).data();

      for (var key in data) {
        if (data.hasOwnProperty(key)) {
          var value = data[key];

          // Handle complex data structures (like process-coordinates)
          if (typeof value === 'object' && value !== null) {
            value = JSON.stringify(value);
          }

          $(targetElement).data(key, data[key]);
          targetElement.setAttribute('data-' + this.camelToKebab(key), value);
        }
      }
    },

    camelToKebab: function(str) {
      return str.replace(/([a-z0-9]|(?=[A-Z]))([A-Z])/g, '$1-$2').toLowerCase();
    },

    showFoundationModal: function() {
      var modal = new Foundation.Reveal($('#' + this.modalId));
      modal.open();
    },

    closeModal: function() {
      if (!this.isInModal) return;

      try {
        this.isInModal = false;

        if (this.modalMapElement) {
          var modalMapId = this.modalMapElement.id;

          // Find and destroy the modal map instance
          var instanceIndex = App.Map.instances.findIndex(instance => {
            return instance.map.getContainer().id === modalMapId;
          });

          if (instanceIndex >= 0) {
            var modalMapInstance = App.Map.instances[instanceIndex];
            modalMapInstance.destroy();
            App.Map.instances.splice(instanceIndex, 1);
          }

          this.modalMapElement = null;
        }

        // Clean up escape handler
        if (this.escHandler) {
          document.removeEventListener('keydown', this.escHandler);
          this.escHandler = null;
        }

        // Remove modal HTML
        setTimeout(() => {
          var modalElement = document.getElementById(this.modalId);
          if (modalElement) {
            modalElement.remove();
          }
        }, 50);

      } catch (e) {
        console.error('Error closing Leaflet modal:', e);
        this.isInModal = false;
      }
    }
  });
}
