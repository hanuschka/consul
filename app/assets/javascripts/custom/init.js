(function() {
  "use strict";

  App.CustomJS = {
    initialize: function() {
      App.DropdownMenuComponent.initialize();
      App.ResourcesListComponent.initialize();
      App.StikyHeader.initialize();
      App.DirectUploadComponent.initialize();
      App.ImageUploadComponent.initialize();
      App.TextSearchFormComponent.initialize();
      App.CollapseComponent.initialize();
      App.CustomTabs.initialize();
      App.SidebarCardComponent.initialize();
    }
  };
}).call(this);
