(function() {
    "use strict";
    App.Tags = {
      initialize: function() {
  
        var $tag_input_categories;
        var $tag_input;
        var $tag_input_subcategories;
        $tag_input_categories = $("input.js-tag-list.list-categories");
        $tag_input = $("input.js-tag-list");
        $tag_input_subcategories = $("input.js-tag-list.list-subcategories");
        var current_categories;
        var current_subcategories;
        var current_tags;
        current_categories = ($tag_input_categories.val() || "").split(",").filter(Boolean);
        current_tags = ($tag_input.val() || "").split(",").filter(Boolean);
        current_subcategories = ($tag_input_subcategories.val() || "").split(",").filter(Boolean);
  
        $(".js-add-tag-link").each(function(i, el){
          if(current_categories.indexOf($(el).text()) >= 0){
            $(el).addClass("selected");
          }
          if(current_subcategories.indexOf($(el).text()) >= 0){
            $(el).addClass("selected");
          }
          if(current_tags.indexOf($(el).text()) >= 0){
            $(el).addClass("selected");
          }
        })
  
        $("body").on("click", ".js-add-tag-link", function() {
          var current_tags, name, t_input;
          name = "" + ($(this).text()) + "";
          if ($(this).hasClass("category-tag")){
            current_tags = $tag_input_categories.val().split(",").filter(Boolean);
            t_input = $tag_input_categories;
          }else if ($(this).hasClass("subcategory-tag")){
            current_tags = $tag_input_subcategories.val().split(",").filter(Boolean);
            t_input = $tag_input_subcategories;
          }else{
            current_tags = $tag_input.val().split(",").filter(Boolean);
            t_input = $tag_input;
          }
          if (current_tags.indexOf(name) >= 0) {
            $(this).removeClass("selected")
            current_tags.splice(current_tags.indexOf(name), 1);
          } else {
            $(this).addClass("selected")
            current_tags.push(name);
          }
          t_input.val(current_tags.join(","));
          return false;
        });
      }
    };
  }).call(this);