import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab"]
  static values = {
    aiSections: Array,
    sharedSections: Array
  }

  connect() {
    this.moveTabsBelowPhaseHeader()

    const params = new URLSearchParams(window.location.search)

    this.activeTab = params.get("tab") === "ai" ? "ai" : "stats"
    this.applyActiveTab()
  }

  moveTabsBelowPhaseHeader() {
    const tabBar = this.element.querySelector(".adm-evaluation-view-tabs")
    const phaseHeaderSection = this.element.querySelector('.phase-evaluation-section[data-section="kpis"]')

    if (!tabBar) return
    if (!phaseHeaderSection) return

    phaseHeaderSection.after(tabBar)
  }

  select(event) {
    const tab = event.currentTarget.dataset.tab

    if (tab === this.activeTab) return

    this.activeTab = tab
    this.applyActiveTab()
    this.syncUrl()
    this.notifyCharts()
  }

  applyActiveTab() {
    this.tabTargets.forEach((button) => {
      const active = button.dataset.tab === this.activeTab

      button.classList.toggle("-active", active)
      button.setAttribute("aria-selected", active ? "true" : "false")
    })

    this.sections().forEach((section) => {
      section.hidden = !this.sectionVisible(section.dataset.section)
    })
  }

  sectionVisible(key) {
    if (this.sharedSectionsValue.includes(key)) return true

    const aiSection = this.aiSectionsValue.includes(key)

    return this.activeTab === "ai" ? aiSection : !aiSection
  }

  sections() {
    return this.element.querySelectorAll(".phase-evaluation-section[data-section]")
  }

  syncUrl() {
    const url = new URL(window.location.href)

    if (this.activeTab === "ai") {
      url.searchParams.set("tab", "ai")
    } else {
      url.searchParams.delete("tab")
    }

    window.history.replaceState(window.history.state, "", url)
  }

  notifyCharts() {
    document.dispatchEvent(new CustomEvent("adm-charts:resize"))
  }
}
