import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {
  static values = {
    url: String
  }

  connect() {
    this.sortable = Sortable.create(this.element, {
      animation: 150,
      onEnd: (event) => {
        const newOrder = Array.from(this.element.children).map((child) => child.dataset.id)

        fetch(this.urlValue, {
          method: "PATCH",
          headers: {
            "Content-Type": "application/json",
            "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').getAttribute('content')
          },
          body: JSON.stringify({ ordered_list: newOrder })
        })
      }
    })
  }
}
