
(function() {
  "use strict";
  App.CollapseComponent = {
    initialized: false,

    initialize: function() {
      if (!this.initialized) {
        $(document).on("click", ".js-collapse-head", this.toggleCollapse.bind(this));
      }

      this.initialized = true;
    },

    toggleCollapse: function(e) {
      e.stopPropagation();
      var parentElement = e.currentTarget.parentElement;
      parentElement.classList.toggle("-opened");

      var isExpanded = parentElement.classList.contains("-opened");
      e.currentTarget.setAttribute("aria-expanded", isExpanded);
    }
  };
}).call(this);
