import { Controller } from "@hotwired/stimulus"

// Handles user search and selection within a form.
// The search is performed via a Turbo Stream POST request,
// and the selected user's ID is stored in a hidden field.
export default class extends Controller {
  static targets = ["input", "results", "hiddenField", "selectedDisplay", "searchArea"]
  static values = { url: String, minLength: { type: Number, default: 2 } }

  search() {
    const query = this.inputTarget.value.trim()

    if (query.length < this.minLengthValue) {
      this.resultsTarget.innerHTML = ""
      return
    }

    const formData = new FormData()
    formData.append("search", query)

    const csrfToken = document.querySelector("meta[name='csrf-token']")?.content

    fetch(this.urlValue, {
      method: "POST",
      headers: {
        "Accept": "text/vnd.turbo-stream.html",
        "X-CSRF-Token": csrfToken
      },
      body: formData
    })
      .then(response => response.text())
      .then(html => {
        Turbo.renderStreamMessage(html)
      })
  }

  selectUser(event) {
    const button = event.currentTarget
    const userId = button.dataset.userId
    const userName = button.dataset.userName
    const userEmail = button.dataset.userEmail

    this.hiddenFieldTarget.value = userId
    this.selectedDisplayTarget.innerHTML = this.buildSelectedHtml(userName, userEmail)
    this.selectedDisplayTarget.classList.remove("d-none")
    this.searchAreaTarget.classList.add("d-none")
    this.resultsTarget.innerHTML = ""
    this.inputTarget.value = ""
  }

  clearSelection() {
    this.hiddenFieldTarget.value = ""
    this.selectedDisplayTarget.innerHTML = ""
    this.selectedDisplayTarget.classList.add("d-none")
    this.searchAreaTarget.classList.remove("d-none")
  }

  buildSelectedHtml(name, email) {
    return `
      <div class="d-flex justify-content-between align-items-center p-3" style="background: #f0fdf4; border: 1px solid #bbf7d0; border-radius: 6px;">
        <span><strong>${this.escapeHtml(name)}</strong> (${this.escapeHtml(email)})</span>
        <button type="button" style="background: none; border: none; cursor: pointer; color: #64748b; padding: 0;"
          data-action="click->adm-user-select#clearSelection">
          <span class="material-symbols-outlined" aria-hidden="true">close</span>
        </button>
      </div>
    `
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
