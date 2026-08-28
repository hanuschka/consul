import { Controller } from "@hotwired/stimulus"

// Consumer glue for the <custom-tabs> element on the phase evaluation page. The
// element owns all tab behaviour (active state, ARIA, panel visibility, URL
// sync); this controller only reacts to its "custom-tabs:change" event to do
// the evaluation-specific work the element must stay ignorant of: swapping the
// regenerate button's target/label, toggling per-tab actions, and nudging the
// charts to re-measure.
export default class extends Controller {
  static targets = ["bar", "regenerateButton", "regenerateLabel", "regenerateAiDisabled", "statsAction", "aiAction"]
  static values = {
    regularUrl: String,
    aiUrl: String,
    regularLabel: String,
    aiLabel: String,
    aiRegenBlocked: Boolean
  }

  connect() {
    this.moveTabsBelowPhaseHeader()
    this.reflectTab(this.initialTab())
  }

  change(event) {
    this.reflectTab(event.detail.tab)
    this.notifyCharts()
  }

  initialTab() {
    const aiTab = this.element.querySelector('custom-tab[for="ai"]')

    if (aiTab && aiTab.hasAttribute("disabled")) return "stats"

    const tab = new URLSearchParams(window.location.search).get("tab")

    return tab === "ai" ? "ai" : "stats"
  }

  reflectTab(tab) {
    const isAi = tab === "ai"

    this.updateRegenerateButton(isAi)
    this.updateTabActions(isAi)
  }

  updateRegenerateButton(isAi) {
    if (!this.hasRegenerateButtonTarget) return

    const blockAi = isAi && this.aiRegenBlockedValue

    this.regenerateButtonTarget.hidden = blockAi

    if (this.hasRegenerateAiDisabledTarget) this.regenerateAiDisabledTarget.hidden = !blockAi

    if (blockAi) return

    this.regenerateButtonTarget.href = isAi ? this.aiUrlValue : this.regularUrlValue

    if (this.hasRegenerateLabelTarget) {
      this.regenerateLabelTarget.textContent = isAi ? this.aiLabelValue : this.regularLabelValue
    }
  }

  updateTabActions(isAi) {
    if (this.hasStatsActionTarget) this.statsActionTarget.hidden = isAi
    if (this.hasAiActionTarget) this.aiActionTarget.hidden = !isAi
  }

  moveTabsBelowPhaseHeader() {
    if (!this.hasBarTarget) return

    const kpis = this.element.querySelector('[data-section="kpis"]')

    if (!kpis) return

    const anchor = kpis.closest("custom-tab-panel") || kpis
    anchor.after(this.barTarget)
  }

  notifyCharts() {
    document.dispatchEvent(new CustomEvent("adm-charts:resize"))
  }
}
