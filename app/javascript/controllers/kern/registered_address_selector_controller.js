import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["city", "streetWrapper", "streetSelect", "addressWrapper", "addressSelect", "regularFields"]

  static values = {
    streetsUrl: String,
    addressesUrl: String,
    notInListLabel: String
  }

  cityChanged() {
    const cityId = this.cityTarget.value

    this.clearSelect(this.streetSelectTarget)
    this.hide(this.addressWrapperTarget)
    this.clearSelect(this.addressSelectTarget)

    if (cityId === "" || cityId === null) {
      this.hide(this.streetWrapperTarget)
      this.hideRegularFields()
      return
    }

    if (cityId === "0") {
      this.hide(this.streetWrapperTarget)
      this.showRegularFields()
      return
    }

    this.fetchOptions(`${this.streetsUrlValue}?city_id=${cityId}`, this.streetSelectTarget)
      .then(() => this.show(this.streetWrapperTarget))

    this.hideRegularFields()
  }

  streetChanged() {
    const streetId = this.streetSelectTarget.value

    this.clearSelect(this.addressSelectTarget)

    if (streetId === "" || streetId === null) {
      this.hide(this.addressWrapperTarget)
      this.hideRegularFields()
      return
    }

    if (streetId === "0") {
      this.hide(this.addressWrapperTarget)
      this.showRegularFields()
      return
    }

    this.fetchOptions(`${this.addressesUrlValue}?street_id=${streetId}`, this.addressSelectTarget)
      .then(() => this.show(this.addressWrapperTarget))

    this.hideRegularFields()
  }

  addressChanged() {
    const addressId = this.addressSelectTarget.value

    if (addressId === "0") {
      this.showRegularFields()
    } else {
      this.hideRegularFields()
    }
  }

  // Private

  fetchOptions(url, selectElement) {
    return fetch(url, {
      headers: { "Accept": "application/json" }
    })
      .then(response => response.json())
      .then(options => {
        const notInList = this.notInListLabelValue
        this.clearSelect(selectElement)

        options.forEach(opt => {
          selectElement.add(new Option(opt.label, opt.value))
        })

        selectElement.add(new Option(notInList, "0"))
      })
      .catch(error => console.error("RegisteredAddressSelector fetch error:", error))
  }

  clearSelect(selectElement) {
    const prompt = selectElement.options[0]
    selectElement.innerHTML = ""
    if (prompt && prompt.value === "") {
      selectElement.add(prompt)
    }
    selectElement.selectedIndex = 0
  }

  show(element) {
    element.style.display = "block"
  }

  hide(element) {
    element.style.display = "none"
  }

  showRegularFields() {
    if (this.hasRegularFieldsTarget) {
      this.show(this.regularFieldsTarget)
    }
  }

  hideRegularFields() {
    if (this.hasRegularFieldsTarget) {
      this.hide(this.regularFieldsTarget)
    }
  }
}
