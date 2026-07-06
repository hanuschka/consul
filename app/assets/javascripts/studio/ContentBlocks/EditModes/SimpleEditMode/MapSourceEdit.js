// Resource/phase source control for map content blocks in simple edit mode.
//
// A map content block persists its data source as data-map-resource /
// data-map-phase-id on the .js-projekt-map-embed wrapper (both attributes are
// on the admin WYSIWYG allowlists, Ruby + JS mirror). This module injects a
// frosted-glass panel with two selects into the bottom-center of each embed:
// the resource (projekt location, proposals, investments, points of interest,
// all-projekts overview) and — for phase-bound resources — the projekt phase,
// filtered to the phases matching the selected resource type.
//
// Changing a select updates the wrapper's data attributes and re-hydrates the
// embed via App.Studio.ContentBlocks.MapEmbed, so the preview shows the exact
// markup the server renders on the published page. The panel itself must never
// reach the saved body: App.Studio.utils.resetMapEmbeds strips
// .js-map-source-control while keeping the wrapper and its data attributes.
App.Studio.ContentBlocks.SimpleEditMode.MapSourceEdit = {
  controlClass: "js-map-source-control",
  embedSelector: ".js-projekt-map-embed",
  resourceSelector: ".js-map-source-resource",
  phaseSelector: ".js-map-source-phase",
  phaseFieldSelector: ".js-map-source-phase-field",
  defaultResource: "projekt_location",
  allPhasesValue: "all",

  // The control is only injected on projekt pages (see available()), so the
  // all-projekts overview map is intentionally not offered here — it is the
  // default for embeds outside a projekt context (e.g. the homepage).
  resourceOptions: [
    { value: "projekt_location", label: "Projekt-Standort" },
    { value: "proposals", label: "Vorschläge" },
    { value: "investments", label: "Budget" },
    { value: "points_of_interest", label: "Orte von Interesse" }
  ],

  // Mirror of HasEmbeddableShortcodes::PHASE_RESOURCE_SOURCES (source key):
  // maps a phase-bound resource to the ProjektPhase#name it pulls phases from.
  resourceSources: {
    proposals: "proposal_phase",
    investments: "budget_phase",
    points_of_interest: "point_of_interest_phase"
  },

  initialize() {
    this.initEventListeners()
  },

  initEventListeners() {
    const $document = $(document);

    $document.on("change", this.resourceSelector, this.handleResourceChange.bind(this));
    $document.on("change", this.phaseSelector, this.handlePhaseChange.bind(this));
  },

  toggleMapControls(contentBlock, enabled) {
    const embeds = contentBlock.querySelectorAll(this.embedSelector);

    if (enabled) {
      embeds.forEach((embed) => this.addControlToEmbed(embed))
    } else {
      embeds.forEach((embed) => this.removeControlFromEmbed(embed))
    }
  },

  addControlToEmbed(embed) {
    if (!this.available()) return
    if (embed.querySelector("." + this.controlClass)) return

    embed.appendChild(this.buildControl(embed))
  },

  removeControlFromEmbed(embed) {
    const control = embed.querySelector("." + this.controlClass)

    if (control) control.remove()
  },

  // The control only makes sense where phase data is available — the projekt
  // page emits data-studio-projekt-phases for admins/PMs. On the homepage the
  // default already is the all-projekts map and phase resources need a
  // projekt, so no control is injected there.
  available() {
    const page = this.getProjektPage()

    return !!(page && page.dataset.studioProjektPhases)
  },

  getProjektPage() {
    return document.querySelector(".js-projekt-page")
  },

  buildControl(embed) {
    const control = document.createElement("div")
    control.className =
      `${this.controlClass} studio-content-block-map-source-control ` +
      "js-studio-hide-on-preview js-content-block-element-not-editable"
    control.contentEditable = false

    const resource = this.currentResource(embed)

    control.innerHTML = `
      <span class="studio-content-block-map-source-control--field">
        <span class="studio-content-block-map-source-control--label">
          <i class="fas fa-map-marked-alt studio-content-block-map-source-control--icon"></i>
          Inhalt
        </span>
        <select
          class="studio-content-block-map-source-control--select js-map-source-resource"
          aria-label="Karteninhalt auswählen"
        ></select>
      </span>
      <span class="studio-content-block-map-source-control--field js-map-source-phase-field">
        <span class="studio-content-block-map-source-control--label">Phase</span>
        <select
          class="studio-content-block-map-source-control--select js-map-source-phase"
          aria-label="Phase auswählen"
        ></select>
      </span>
    `

    this.populateResourceSelect(control.querySelector(this.resourceSelector), resource)
    this.populatePhaseSelect(
      control.querySelector(this.phaseSelector), resource, this.currentPhaseId(embed)
    )
    this.togglePhaseField(control, resource)

    return control
  },

  populateResourceSelect(select, selectedResource) {
    this.fillSelect(select, this.resourceOptions, selectedResource, this.defaultResource)
  },

  populatePhaseSelect(select, resource, selectedPhaseId) {
    const options = [{ value: this.allPhasesValue, label: "Alle Phasen" }]

    this.phasesForResource(resource).forEach((phase) => {
      options.push({ value: String(phase.id), label: phase.label })
    })

    this.fillSelect(select, options, String(selectedPhaseId), this.allPhasesValue)
  },

  // Options are built via createElement/textContent (not innerHTML) because
  // phase labels are admin-entered text.
  fillSelect(select, options, selectedValue, fallbackValue) {
    select.innerHTML = ""

    options.forEach((entry) => {
      const option = document.createElement("option")
      option.value = entry.value
      option.textContent = entry.label
      select.appendChild(option)
    })

    const known = options.some((entry) => entry.value === selectedValue)

    select.value = known ? selectedValue : fallbackValue
  },

  projektPhases() {
    const page = this.getProjektPage()

    if (!page || !page.dataset.studioProjektPhases) return []

    try {
      return JSON.parse(page.dataset.studioProjektPhases)
    } catch (error) {
      return []
    }
  },

  phasesForResource(resource) {
    const source = this.resourceSources[resource]

    if (!source) return []

    return this.projektPhases().filter((phase) => phase.name === source)
  },

  // Falls back to the default for values no longer offered (e.g. an embed
  // saved with "projekts" before that option was removed from the control).
  currentResource(embed) {
    const stored = embed.dataset.mapResource
    const known = this.resourceOptions.some((option) => option.value === stored)

    return known ? stored : this.defaultResource
  },

  currentPhaseId(embed) {
    return embed.dataset.mapPhaseId || this.allPhasesValue
  },

  getEmbedFromControl(element) {
    return element.closest(this.embedSelector);
  },

  handleResourceChange(e) {
    const select = e.currentTarget;
    const embed = this.getEmbedFromControl(select);

    if (!embed) return

    const resource = select.value;
    const control = select.closest("." + this.controlClass);

    embed.dataset.mapResource = resource;
    embed.dataset.mapPhaseId = this.allPhasesValue;

    this.populatePhaseSelect(
      control.querySelector(this.phaseSelector), resource, this.allPhasesValue
    );
    this.togglePhaseField(control, resource);

    App.Studio.ContentBlocks.MapEmbed.rehydrate(embed);
  },

  handlePhaseChange(e) {
    const select = e.currentTarget;
    const embed = this.getEmbedFromControl(select);

    if (!embed) return

    embed.dataset.mapPhaseId = select.value;

    App.Studio.ContentBlocks.MapEmbed.rehydrate(embed);
  },

  togglePhaseField(control, resource) {
    const field = control.querySelector(this.phaseFieldSelector);

    field.classList.toggle("-hidden", !this.resourceSources[resource]);
  },
}
