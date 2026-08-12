(function() {
  "use strict";
  App.DeficiencyReportSubcategories = {
    // The subcategory select ships with every option in the document and keeps them in memory, so
    // switching category re-filters without a round trip. Options are removed rather than hidden:
    // a hidden <option> stays selectable in several browsers.
    initialize: function() {
      var categorySelect, subcategorySelect, wrapper, allOptions;

      categorySelect = $(".js-user-resource-select-category");
      subcategorySelect = $(".js-deficiency-report-subcategory-select");
      wrapper = $(".js-deficiency-report-subcategory-wrapper");

      if (!categorySelect.length || !subcategorySelect.length) {
        return;
      }

      allOptions = subcategorySelect.find("option").clone();

      var refresh = function() {
        var categoryId, selected, matching;

        categoryId = categorySelect.val();
        selected = subcategorySelect.val();

        matching = allOptions.filter(function() {
          var optionCategory = $(this).data("category-id");
          return !optionCategory || String(optionCategory) === String(categoryId);
        });

        subcategorySelect.empty().append(matching.clone());

        if (subcategorySelect.find("option[value='" + selected + "']").length) {
          subcategorySelect.val(selected);
        }

        // A category without subcategories shows none at all, rather than an empty dropdown.
        wrapper.toggle(subcategorySelect.find("option[value!='']").length > 0);
      };

      categorySelect.on("change", refresh);
      refresh();
    }
  };
}).call(this);
