(function() {
  "use strict";

  App.CustomJS = {
    initialize: function() {
      App.StikyTopbar.initialize();
      App.ResourcesListComponent.initialize();
      App.DropdownMenuComponent.initialize();
    }
  };
}).call(this);
