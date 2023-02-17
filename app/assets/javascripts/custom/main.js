(function() {
  "use strict";

  App.CustomJS = {
    initialize: function() {
      App.FooterPhasesComponentCustom.initialize();
      App.ProjektQuestionCustom.initialize();
      App.LivesubmitCheckboxCustom.initialize();
      App.OrbitInPopupFixCustom.initialize();
      App.ResourcesListComponent.initialize();
      App.DropdownMenuComponent.initialize();
      App.ModalNotification.initialize();
      App.StikyHeader.initialize();
      App.DirectUploadComponent.initialize();
    }
  };
}).call(this);
