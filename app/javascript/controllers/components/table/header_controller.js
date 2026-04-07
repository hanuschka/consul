import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { column: String }
  static targets = [ "filterMenu", "searchInput" ]

  connect() {
    this.url = new URL(window.location);
  }

  toggleFilterMenu(event) {
    event.stopPropagation();
    event.preventDefault();

    this.filterMenuTarget.classList.toggle("d-none");

    const wrapper = this.element.closest(".kern-table-responsive");
    if (wrapper) {
      wrapper.style.overflow = this.filterMenuTarget.classList.contains("d-none") ? "" : "visible";
    }
  }

  selectFilterOption(event) {
    const paramName = `${this.columnValue}[]`;

    const selectedOptions = Array.from(
      this.element.querySelectorAll(`input:checked`)
    ).map(input => input.value);

    this.url.searchParams.delete(paramName);
    selectedOptions.forEach(value => {
      this.url.searchParams.append(paramName, value);
    });
  }

  applyFilter() {
    if (this.hasSearchInputTarget) {
      const searchValue = this.searchInputTarget.value.trim();
      if (searchValue !== "") {
        this.url.searchParams.set(this.searchInputTarget.name, searchValue);
      } else {
        this.url.searchParams.delete(this.searchInputTarget.name);
      }
    }

    window.location.href = this.url.toString();
  }
}
