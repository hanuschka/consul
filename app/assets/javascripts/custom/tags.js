(function() {
  "use strict";
  App.Tags = {
    initialize: function() {
      var $tag_input = $("input.js-tag-list.predefined");
      var current_tags;
      current_tags = ($tag_input.val() || "").split(",").filter(Boolean);

      $(".js-add-tag-link").each(function(i, el){
        if(current_tags.indexOf($(el).text()) >= 0){
          $(el).addClass("selected");
        }
      })

      $("body").on("click", ".js-add-tag-link", function() {
        var current_tags, name, t_input;
        name = "" + ($(this).text()) + "";

        current_tags = $tag_input.val().split(",").filter(Boolean);
        t_input = $tag_input;

        if (current_tags.indexOf(name) >= 0) {
          $(this).removeClass("selected")
          current_tags.splice(current_tags.indexOf(name), 1);
        } else {
          $(this).addClass("selected")
          current_tags.push(name);
        }
        t_input
          .val(current_tags.join(","))
          .trigger("change");

        return false;
      });
    }
  };
}).call(this);
