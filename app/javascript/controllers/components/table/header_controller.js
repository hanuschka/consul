import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { column: String }
  static targets = [ "filterMenu", "searchInput", "dateFromInput", "dateToInput" ]

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
      this.setOrDeleteParam(this.searchInputTarget.name, this.searchInputTarget.value.trim());
    }

    if (this.hasDateFromInputTarget) {
      this.setOrDeleteParam(this.dateFromInputTarget.name, this.dateFromInputTarget.value);
    }

    if (this.hasDateToInputTarget) {
      this.setOrDeleteParam(this.dateToInputTarget.name, this.dateToInputTarget.value);
    }

    window.location.href = this.url.toString();
  }

  setOrDeleteParam(name, value) {
    if (value && value !== "") {
      this.url.searchParams.set(name, value);
    } else {
      this.url.searchParams.delete(name);
    }
  }
}
