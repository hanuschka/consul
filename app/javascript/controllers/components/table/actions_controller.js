import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "button", "menu" ]

  connect() {
    this.close = this.close.bind(this);
    this.handleClickOutside = this.handleClickOutside.bind(this);
    document.addEventListener("table-actions:close-all", this.close);
  }

  disconnect() {
    document.removeEventListener("table-actions:close-all", this.close);
    document.removeEventListener("click", this.handleClickOutside);
  }

  handleClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.close();
    }
  }

  toggleMenu(event) {
    event.preventDefault();
    event.stopPropagation();

    document.dispatchEvent(
      new CustomEvent("table-actions:close-all", {
        detail: { source: this }
      })
    )

    this.menuTarget.classList.contains("d-none") ? this.open() : this.close();
  }

  open() {
    this.menuTarget.classList.remove("d-none");
    this.buttonTarget.setAttribute("aria-expanded", "true");
    document.addEventListener("click", this.handleClickOutside);

    requestAnimationFrame(() => {
      this.positionMenu()
    })
  }

  close() {
    if (event?.detail?.source === this) return;

    this.menuTarget.classList.add("d-none");
    this.buttonTarget.setAttribute("aria-expanded", "false");
    document.removeEventListener("click", this.handleClickOutside);
  }

  positionMenu() {
    const menu = this.menuTarget;
    menu.classList.remove("kern-table__actions-menu--up");

    const rect = menu.getBoundingClientRect();
    const tableRect = this.element.closest("table").getBoundingClientRect();

    if (rect.bottom > tableRect.bottom) {
      menu.classList.add("kern-table__actions-menu--up");
    }
  }
}
