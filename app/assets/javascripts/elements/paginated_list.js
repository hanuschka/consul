(function() {
  "use strict";

  // <paginated-list per="10"> paginates its item children entirely on the
  // client, so it works identically in both JS packs (main app + /adm) without
  // any framework dependency. The paginated units are the direct children of
  // the element marked [data-paginated-list-items]; prev/next controls and a
  // status label are appended after that container. When the item count is at
  // or below `per`, no controls render and everything stays visible.
  // Styles live in app/assets/stylesheets/elements/paginated_list.scss.
  //
  // Attributes (all optional):
  //   per             items per page (default 10, minimum 1)
  //   previous-label  previous-button label
  //   next-label      next-button label
  //   status-label    template with {current}/{total} placeholders
  class PaginatedList extends HTMLElement {
    connectedCallback() {
      if (this.initialized) return;

      this.container = this.querySelector("[data-paginated-list-items]");
      if (!this.container) return;

      this.items = Array.from(this.container.children);
      this.perPage = Math.max(parseInt(this.getAttribute("per"), 10) || 10, 1);

      if (this.items.length <= this.perPage) return;

      this.pageCount = Math.ceil(this.items.length / this.perPage);
      this.currentPage = 0;

      this.buildControls();
      this.update();
      this.initialized = true;
    }

    buildControls() {
      this.controls = document.createElement("div");
      this.controls.className = "paginated-list--controls";

      this.previousButton = this.buildButton(
        this.getAttribute("previous-label") || "",
        () => this.goTo(this.currentPage - 1)
      );

      this.status = document.createElement("span");
      this.status.className = "paginated-list--status";
      this.status.setAttribute("aria-live", "polite");

      this.nextButton = this.buildButton(
        this.getAttribute("next-label") || "",
        () => this.goTo(this.currentPage + 1)
      );

      this.controls.appendChild(this.previousButton);
      this.controls.appendChild(this.status);
      this.controls.appendChild(this.nextButton);
      this.appendChild(this.controls);
    }

    buildButton(label, onClick) {
      const button = document.createElement("button");
      button.type = "button";
      button.className = "paginated-list--button";
      button.textContent = label;
      button.addEventListener("click", onClick);

      return button;
    }

    goTo(page) {
      this.currentPage = Math.min(Math.max(page, 0), this.pageCount - 1);
      this.update();
    }

    update() {
      const start = this.currentPage * this.perPage;
      const end = start + this.perPage;

      this.items.forEach((item, index) => {
        item.hidden = index < start || index >= end;
      });

      const template = this.getAttribute("status-label") || "{current} / {total}";
      this.status.textContent = template
        .replace("{current}", this.currentPage + 1)
        .replace("{total}", this.pageCount);

      this.previousButton.disabled = this.currentPage === 0;
      this.nextButton.disabled = this.currentPage === this.pageCount - 1;
    }
  }

  if (!customElements.get("paginated-list")) {
    customElements.define("paginated-list", PaginatedList);
  }
})();
