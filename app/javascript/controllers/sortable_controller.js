import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {
  static values = { url: String, maxDepth: Number }

  connect() {
    this.maxDepthValue ||= 2
    this.initContainer(this.element, 1)
  }

  initContainer(container, depth) {
    Sortable.create(container, {
      group: "nested",
      animation: 150,
      handle: "[data-sortable-handle]",
      draggable: "[data-sortable-id]",
      fallbackOnBody: true,
      swapThreshold: 0.65,
      onEnd: (event) => this.save(),
      onMove: (event) => {
        const newParent = event.to.closest("[data-sortable-id]") || this.element
        const newDepth = this.computeDepth(newParent)
        return newDepth <= this.maxDepthValue
      }
    })

    container
      .querySelectorAll(":scope > [data-sortable-id] > [data-sortable-children]")
      .forEach((childContainer) => this.initContainer(childContainer))
  }

  computeDepth(element) {
    let depth = 1
    let current = element

    while (current && current !== this.element) {
      if (current.hasAttribute("data-sortable-id")) depth++
      current = current.parentElement
    }

    return depth
  }

  save() {
    fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').getAttribute('content')
      },
      body: JSON.stringify({
        tree: this.serialize(this.element)
      })
    })
  }

  serialize(container) {
    return Array.from(container.children)
      .filter((child) => child.hasAttribute("data-sortable-id"))
      .map((child) => {
        const childrenContainer = child.querySelector("[data-sortable-children]")

        return {
          id: child.dataset.sortableId,
          children: childrenContainer ? this.serialize(childrenContainer) : []
        }
      })
  }
}
