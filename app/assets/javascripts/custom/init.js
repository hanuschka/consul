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
      App.CkeEditorPlaceholder.initialize();
      App.QuestionWizard.initialize();
      App.AutosubmitFormElement.initialize();
      App.NewSortable.initialize();
      App.SidebarFilterComponent.initialize();
    }
  };
}).call(this);
