import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["scrollContainer", "leftArrow", "rightArrow"]

  connect() {
    this.scrollActiveTabIntoView()
    this.updateArrowVisibility()
    this.scrollContainerTarget.addEventListener("scroll", () => this.updateArrowVisibility())
    window.addEventListener("resize", () => this.updateArrowVisibility())
  }

  scrollActiveTabIntoView() {
    const activeTab = this.scrollContainerTarget.querySelector(".adm-tab.active")
    if (!activeTab) return

    const container = this.scrollContainerTarget
    const tabLeft = activeTab.offsetLeft
    const tabRight = tabLeft + activeTab.offsetWidth
    const containerScrollLeft = container.scrollLeft
    const containerVisibleRight = containerScrollLeft + container.clientWidth

    if (tabLeft < containerScrollLeft) {
      container.scrollLeft = tabLeft
    } else if (tabRight > containerVisibleRight) {
      container.scrollLeft = tabRight - container.clientWidth
    }
  }

  disconnect() {
    window.removeEventListener("resize", () => this.updateArrowVisibility())
  }

  scrollLeft() {
    this.scrollContainerTarget.scrollBy({ left: -150, behavior: "smooth" })
  }

  scrollRight() {
    this.scrollContainerTarget.scrollBy({ left: 150, behavior: "smooth" })
  }

  updateArrowVisibility() {
    const container = this.scrollContainerTarget
    const scrollLeft = container.scrollLeft
    const scrollWidth = container.scrollWidth
    const clientWidth = container.clientWidth

    if (this.hasLeftArrowTarget) {
      this.leftArrowTarget.classList.toggle("hidden", scrollLeft <= 0)
    }

    if (this.hasRightArrowTarget) {
      this.rightArrowTarget.classList.toggle("hidden", scrollLeft + clientWidth >= scrollWidth - 1)
    }
  }
}
