(function() {
  "use strict";
  App.TagFilter = {
    initialize() {
      $("body").on("click", ".js-tag-filter-toggle", this.toggleTag.bind(this));
    },

    toggleTag(event) {
      const filterElement = event.currentTarget.closest(".js-tag-filter");
      const selectedTags = this.selectedTags(filterElement);
      const tagName = event.currentTarget.dataset.tagName;
      const tagIndex = selectedTags.indexOf(tagName);

      if (tagIndex > -1) {
        selectedTags.splice(tagIndex, 1);
      } else {
        selectedTags.push(tagName);
      }

      Turbolinks.visit(this.filterUrl(filterElement, selectedTags));
    },

    selectedTags(filterElement) {
      const selectedTagsValue = filterElement.dataset.selectedTags;

      return selectedTagsValue ? selectedTagsValue.split(",") : [];
    },

    // Tags are joined with a literal comma so the address bar stays readable;
    // a tag name can never contain one, since the server splits on it.
    filterUrl(filterElement, selectedTags) {
      const url = new URL(filterElement.dataset.tagFilterBasePath, window.location.origin);

      if (selectedTags.length === 0) return url.toString();

      const tagsParam = selectedTags.sort().map(encodeURIComponent).join(",");
      const separator = url.search ? "&" : "?";

      return url.toString() + separator + "tags=" + tagsParam;
    }
  };
}).call(this);
