import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "button", "menu" ]

  connect() {
    this.close = this.close.bind(this);
    this.handleClickOutside = this.handleClickOutside.bind(this);
    this.handleWindowScroll = this.handleWindowScroll.bind(this);
    this.handleBeforeCache = this.handleBeforeCache.bind(this);
    document.addEventListener("table-actions:close-all", this.close);
    document.addEventListener("turbo:before-cache", this.handleBeforeCache);
  }

  disconnect() {
    document.removeEventListener("table-actions:close-all", this.close);
    document.removeEventListener("click", this.handleClickOutside);
    window.removeEventListener("scroll", this.handleWindowScroll);
    document.removeEventListener("turbo:before-cache", this.handleBeforeCache);
  }

  handleBeforeCache() {
    this.menuTarget.classList.add("d-none");
    this.buttonTarget.setAttribute("aria-expanded", "false");
  }

  handleClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.close();
    }
  }

  handleWindowScroll() {
    this.close();
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
    window.addEventListener("scroll", this.handleWindowScroll);

    requestAnimationFrame(() => {
      this.positionMenu()
    })
  }

  close() {
    if (event?.detail?.source === this) return;

    this.menuTarget.classList.add("d-none");
    this.buttonTarget.setAttribute("aria-expanded", "false");
    document.removeEventListener("click", this.handleClickOutside);
    window.removeEventListener("scroll", this.handleWindowScroll);
  }

  positionMenu() {
    const menu = this.menuTarget;
    const button = this.buttonTarget;
    const buttonRect = button.getBoundingClientRect();
    const viewportHeight = window.innerHeight;
    const viewportWidth = window.innerWidth;
    const padding = 8;

    menu.style.top = "";
    menu.style.bottom = "";
    menu.style.left = "";
    menu.style.right = "";
    menu.style.maxHeight = "";
    menu.style.overflowY = "";

    menu.style.left = `${buttonRect.left}px`;
    menu.style.top = `${buttonRect.bottom}px`;

    const menuRect = menu.getBoundingClientRect();

    const spaceBelow = viewportHeight - buttonRect.bottom - padding;
    const spaceAbove = buttonRect.top - padding;

    if (menuRect.height > spaceBelow) {
      if (spaceAbove > spaceBelow) {
        menu.style.top = "";
        menu.style.bottom = `${viewportHeight - buttonRect.top}px`;
        menu.style.maxHeight = `${spaceAbove}px`;
      } else {
        menu.style.maxHeight = `${spaceBelow}px`;
      }
      menu.style.overflowY = "auto";
    }

    if (menuRect.right > viewportWidth) {
      menu.style.left = "";
      menu.style.right = `${viewportWidth - buttonRect.right}px`;
    }
  }
}
