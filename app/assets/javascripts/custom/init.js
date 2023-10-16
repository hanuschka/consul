(function() {
  "use strict";

  App.CustomJS = {
    initialize: function() {
      App.DropdownMenuComponent.initialize();
      App.ResourcesListComponent.initialize();
      // App.MobileScrollNavigation.initialize();
      App.DirectUploadComponent.initialize();
      App.ImageUploadComponent.initialize();
      App.TextSearchFormComponent.initialize();
      App.CollapseComponent.initialize();
      App.CustomTabs.initialize();
    }
  };
}).call(this);
