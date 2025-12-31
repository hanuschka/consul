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
  }

  selectFilterOption(event) {
    const checkbox = event.target;

    const selectedOptions = Array.from(
      this.element.querySelectorAll(`input:checked`)
    ).map(input => input.value);

    if (selectedOptions.length > 0) {
      this.url.searchParams.set(`${this.columnValue}`, selectedOptions.join(","));
    } else {
      this.url.searchParams.delete(`${this.columnValue}`);
    }
  }

  applyFilter() {
    if (this.searchInputTarget.value.trim() !== "") {
      this.url.searchParams.set("search", this.searchInputTarget.value.trim());
    }

    window.location.href = this.url.toString();
  }
}
