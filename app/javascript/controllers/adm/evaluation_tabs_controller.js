import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "bar", "regenerateButton", "regenerateLabel"]
  static values = {
    aiSections: Array,
    sharedSections: Array,
    regularUrl: String,
    aiUrl: String,
    regularLabel: String,
    aiLabel: String
  }

  connect() {
    this.moveTabsBelowPhaseHeader()

    const params = new URLSearchParams(window.location.search)

    this.activeTab = params.get("tab") === "ai" ? "ai" : "stats"
    this.applyActiveTab()
  }

  moveTabsBelowPhaseHeader() {
    const bar = this.hasBarTarget ? this.barTarget : this.element.querySelector(".adm-evaluation-view-tabs")
    const phaseHeaderSection = this.element.querySelector('.phase-evaluation-section[data-section="kpis"]')

    if (!bar) return
    if (!phaseHeaderSection) return

    phaseHeaderSection.after(bar)
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

    this.updateRegenerateButton()
  }

  updateRegenerateButton() {
    if (!this.hasRegenerateButtonTarget) return

    const isAi = this.activeTab === "ai"

    this.regenerateButtonTarget.href = isAi ? this.aiUrlValue : this.regularUrlValue

    if (this.hasRegenerateLabelTarget) {
      this.regenerateLabelTarget.textContent = isAi ? this.aiLabelValue : this.regularLabelValue
    }
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
