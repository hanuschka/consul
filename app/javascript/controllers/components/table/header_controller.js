import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { column: String, keepEmpty: Boolean }
  static targets = [ "filterMenu", "searchInput", "dateFromInput", "dateToInput" ]

  connect() {
    this.frame = this.element.closest("turbo-frame");
    this.url = new URL(this.frame?.src || window.location, window.location.origin);
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
    if (selectedOptions.length === 0 && this.keepEmptyValue) {
      this.url.searchParams.append(paramName, "");
    }
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

    if (this.frame) {
      this.frame.src = this.url.toString();
    } else {
      window.location.href = this.url.toString();
    }
  }

  setOrDeleteParam(name, value) {
    if (value && value !== "") {
      this.url.searchParams.set(name, value);
    } else {
      this.url.searchParams.delete(name);
    }
  }
}
