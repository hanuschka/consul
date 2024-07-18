(function() {
  "use strict";
  App.NewSortable = {
    initialize: function() {
      $(".js-new-sortable").sortable({
        scrollSpeed: 20,
        scrollSensitivity: 100,
        create: function(e) {
          var handler = this.dataset.handler;

          if (handler) {
            $(e.target).sortable("option", "handle", handler);
          }
        },

        update: function(e) {
          var new_order = $(this).sortable("toArray", {
            attribute: "data-record-id"
          });

          $.ajax({
            url: $(e.target).data("sort-url"),
            data: {
              ordered_list: new_order
            },
            type: "POST"
          });
        }
      });
    }
  };
}).call(this);
