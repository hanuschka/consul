(function() {
  "use strict";

  App.UserResourceCriteria = {
    initialize() {
      if (!$(".js-criteria-sortable").length) return;
      this.initSortable();
      this.initDelete();
      this.initInlineEdit();
      this.initAddForm();
    },

    getList() {
      return $(".js-criteria-sortable");
    },

    initSortable() {
      this.getList().sortable({
        handle: ".js-criteria-drag-handle",
        stop: this.handleReorder.bind(this)
      });
    },

    handleReorder() {
      const order = $(".js-criteria-item").map(function() {
        return $(this).data("criterionId");
      }).get();
      const url = $(".js-criteria-sortable").data("reorderUrl");
      App.Ajax.patch(url, { order: order });
    },

    initDelete() {
      const $document = $(document);
      $document.on("click", ".js-criteria-delete-btn", function(e) {
        e.preventDefault();
        if (!confirm("Sind Sie sicher, dass Sie dieses Kriterium löschen möchten?")) return;
        const $item = $(this).closest(".js-criteria-item");
        const url = $(this).data("url");
        App.Ajax.delete(url).then(() => $item.remove());
      });
    },

    initInlineEdit() {
      const $document = $(document);
      $document.on("click", ".js-criteria-text", function() {
        const $span = $(this);
        const currentText = $span.text().trim();
        const $input = $("<input>", { type: "text", value: currentText, class: "js-criteria-edit-input" });
        $span.replaceWith($input);
        $input.focus();
        $input.on("blur", App.UserResourceCriteria.saveInlineEdit);
      });
    },

    saveInlineEdit() {
      const $input = $(this);
      const url = $input.closest(".js-criteria-item").data("updateUrl");
      const text = $input.val().trim();
      App.Ajax
        .patch(url, { user_resource_criterion: { text: text } })
        .then(() => {
          $input.replaceWith($("<span>", { class: "js-criteria-text", text: text }));
        });
    },

    initAddForm() {
      const $document = $(document);
      $document.on("submit", ".js-criteria-add-form", function(e) {
        e.preventDefault();
        const $form = $(this);
        const url = $form.attr("action");
        const $input = $form.find(".js-criteria-text-input");
        const text = $input.val().trim();
        if (!text) return;
        App.Ajax
          .post(url, { user_resource_criterion: { text: text } })
          .then((data) => {
            App.UserResourceCriteria.appendCriterion(data, $form);
            $input.val("");
          });
      });
    },

    appendCriterion(data, $form) {
      const template = $(".js-criteria-item-template").html();
      const html = App.htmlTemplateUtils.fillTemplate(template, {
        id: data.id,
        text: data.text,
        updateUrl: $form.data("updateUrlTemplate").replace("CRITERION_ID", data.id),
        deleteUrl: $form.data("deleteUrlTemplate").replace("CRITERION_ID", data.id)
      });
      $(".js-criteria-sortable").append(html);
    }
  };
}).call(this);
