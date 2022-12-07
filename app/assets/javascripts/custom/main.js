(function() {
  "use strict";

  App.CustomJS = {
    initialize: function() {
      App.StikyHeader.initialize();
      App.ResourcesListComponent.initialize();
      App.DropdownMenuComponent.initialize();
    }
  };
}).call(this);
