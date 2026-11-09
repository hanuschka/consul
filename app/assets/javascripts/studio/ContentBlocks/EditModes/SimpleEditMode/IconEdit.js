App.Studio.ContentBlocks.SimpleEditMode.IconEdit = {
  pickableClasses: ["js-content-block-pickable-icon", "studio-content-block-icon-target"],
  lockedSelector: ".js-content-block-element-not-editable",
  excludedIconSelector: ".fa-search-plus, .fa-circle, .projekt-map-embed--pin, .content-block-link-file-icon",
  studioControlSelector: "button, .js-content-block--list-control",
  iconPrefixClasses: ["fa", "fas", "far", "fab"],
  iconModifierPattern: /^fa-(fw|xs|sm|lg|\d+x|li|border|inverse|spin|pulse|pull-(left|right)|flip-(horizontal|vertical|both)|rotate-\d+|stack-[12]x)$/,
  searchDelay: 120,
  currentIcon: null,
  originalClassName: null,
  searchEntries: null,

  initialize() {
    this.filterOptionsDebounced = App.Studio.utils.debounce(
      () => this.filterOptions(this.getSearchInput().value),
      this.searchDelay
    )
    this.initEventListeners()
  },

  initEventListeners() {
    const $document = $(document);

    $document.on("click", ".js-content-block-pickable-icon", this.handleIconClick.bind(this))
    $document.on("click", ".js-content-block-icon-option", this.handleOptionClick.bind(this))
    $document.on("click", ".js-content-block-accept-icon-edit", this.acceptIconEdit.bind(this))
    $document.on("click", ".js-content-block-cancel-icon-edit", this.cancelIconEdit.bind(this))
    $document.on("keydown", ".js-content-block-icon-popup", this.handlePopupKeydown.bind(this))
    $document.on("input", ".js-content-block-icon-search", this.handleSearchInput.bind(this))
    $document.on("mouseenter focusin", ".js-content-block-icon-option", this.handleOptionPointed.bind(this))
    $document.on("mouseleave focusout", ".js-content-block-icon-option", this.showPressedOptionName.bind(this))
  },

  getPopup() {
    return $(".js-content-block-icon-popup");
  },

  getOptions() {
    return document.querySelectorAll(".js-content-block-icon-option");
  },

  getSearchInput() {
    return document.querySelector(".js-content-block-icon-search");
  },

  getSearchStatus() {
    return document.querySelector(".js-content-block-icon-search-status");
  },

  getGroupsContainer() {
    return document.querySelector(".js-content-block-icon-groups");
  },

  getGroups() {
    return document.querySelectorAll(".js-content-block-icon-group");
  },

  getNameLine() {
    return document.querySelector(".js-content-block-icon-name");
  },

  getPressedOption() {
    return document.querySelector(".js-content-block-icon-option[aria-pressed='true']");
  },

  toggleIconControls(contentBlock, enabled) {
    if (enabled) {
      this.markPickableIcons(contentBlock)

      return
    }

    this.closePickerFor(contentBlock)
    this.unmarkPickableIcons(contentBlock)
  },

  markPickableIcons(contentBlock) {
    contentBlock.querySelectorAll("i").forEach((icon) => {
      if (!this.isPickableIcon(icon)) return

      this.getHitTarget(icon).classList.add(...this.pickableClasses)
    })
  },

  unmarkPickableIcons(contentBlock) {
    contentBlock.querySelectorAll(".js-content-block-pickable-icon").forEach((hitTarget) => {
      hitTarget.classList.remove(...this.pickableClasses)

      if (hitTarget.classList.length === 0) {
        hitTarget.removeAttribute("class")
      }
    })
  },

  closePickerFor(contentBlock) {
    if (!this.currentIcon) return
    if (this.currentIcon.isConnected && !contentBlock.contains(this.currentIcon)) return

    this.hidePopup()
  },

  isPickableIcon(icon) {
    if (!this.hasIconNameClass(icon)) return false
    if (icon.matches(this.excludedIconSelector)) return false
    if (icon.closest(this.studioControlSelector)) return false

    return !this.isLocked(icon)
  },

  // A lock on the icon's own icon-only wrapper (the badges of card and CTA
  // templates) only keeps text out; a lock on any larger element keeps the
  // icon as it is.
  isLocked(icon) {
    if (icon.matches(this.lockedSelector)) return true

    const contentBlock = icon.closest(".js-content-block")
    const lockedAncestor = this.getHitTarget(icon).parentElement.closest(this.lockedSelector)

    return Boolean(lockedAncestor) && contentBlock.contains(lockedAncestor)
  },

  getHitTarget(icon) {
    const iconWrapper = icon.parentElement
    const isIconOnlySpan =
      iconWrapper.tagName === "SPAN" &&
      App.Studio.ContentBlocks.SimpleEditMode.isSingleIconSpan(iconWrapper)

    return isIconOnlySpan ? iconWrapper : icon
  },

  hasIconNameClass(icon) {
    return Array.from(icon.classList).some((className) => this.isIconNameClass(className))
  },

  isIconNameClass(className) {
    return className.startsWith("fa-") && !this.iconModifierPattern.test(className)
  },

  getIconName(icon) {
    const iconNameClass = Array.from(icon.classList).find((className) => this.isIconNameClass(className))

    return iconNameClass.replace(/^fa-/, "")
  },

  handleIconClick(e) {
    const hitTarget = e.currentTarget
    const icon = hitTarget.tagName === "I" ? hitTarget : hitTarget.querySelector("i")

    if (!icon || !this.isPickableIcon(icon)) return

    e.preventDefault()
    e.stopPropagation()

    if (icon === this.currentIcon) return

    this.hidePopup()
    this.openPickerFor(icon, hitTarget)
  },

  openPickerFor(icon, hitTarget) {
    this.currentIcon = icon
    this.originalClassName = icon.className
    this.updatePressedOption(icon)
    this.showPressedOptionName()
    this.resetSearch()

    // A click outside keeps the previewed icon, like saving the block does
    App.Studio.ContentBlocks.SimpleEditMode.EditPopup.show(
      this.getPopup(), hitTarget, "below", () => this.hidePopup()
    )

    this.scrollToPressedOption()
    this.getSearchInput().focus()
  },

  // Centers the current icon in the list; scrolls only the list, never the page
  scrollToPressedOption() {
    const container = this.getGroupsContainer()
    const pressedOption = this.getPressedOption()

    container.scrollTop = 0

    if (!pressedOption) return

    const optionTop = pressedOption.getBoundingClientRect().top - container.getBoundingClientRect().top

    container.scrollTop = optionTop - (container.clientHeight - pressedOption.offsetHeight) / 2
  },

  updatePressedOption(icon) {
    const iconName = this.getIconName(icon)

    this.getOptions().forEach((option) => {
      option.setAttribute("aria-pressed", option.dataset.iconName === iconName)
    })
  },

  // The buttons carry their names as aria-labels, so the line under the
  // search field shows them to sighted editors
  handleOptionPointed(e) {
    this.getNameLine().textContent = e.currentTarget.getAttribute("aria-label")
  },

  showPressedOptionName() {
    const pressedOption = this.getPressedOption()

    this.getNameLine().textContent = pressedOption ? pressedOption.getAttribute("aria-label") : ""
  },

  handleSearchInput() {
    this.filterOptionsDebounced()
  },

  resetSearch() {
    this.getSearchInput().value = ""
    this.filterOptions("")
  },

  // Every word of the query has to appear in the icon's German or English
  // terms; a group without a match is hidden with its title.
  filterOptions(query) {
    const queryWords = App.Studio.utils.normalizeSearchText(query).split(/\s+/).filter(Boolean)

    this.getSearchEntries().forEach((entry) => {
      entry.option.hidden = !queryWords.every((word) => entry.terms.includes(word))
    })

    this.getGroups().forEach((group) => {
      group.hidden = !group.querySelector(".js-content-block-icon-option:not([hidden])")
    })

    this.getGroupsContainer().scrollTop = 0
    this.updateSearchStatus()
  },

  // Built once; rebuilt only when the page swapped the picker's markup
  getSearchEntries() {
    if (this.searchEntries && this.searchEntries[0].option.isConnected) {
      return this.searchEntries
    }

    this.searchEntries = Array.from(this.getOptions()).map((option) => ({
      option,
      terms: App.Studio.utils.normalizeSearchText(option.dataset.searchTerms)
    }))

    return this.searchEntries
  },

  updateSearchStatus() {
    const status = this.getSearchStatus()
    const hasVisibleOption = Boolean(
      this.getGroupsContainer().querySelector(".js-content-block-icon-option:not([hidden])")
    )

    status.textContent = hasVisibleOption ? "" : status.dataset.noResultsText
  },

  handleOptionClick(e) {
    e.preventDefault()

    if (!this.currentIcon) return

    const option = e.currentTarget

    this.applyIcon(this.currentIcon, option.dataset.iconStyle, option.dataset.iconName)
    this.updatePressedOption(this.currentIcon)
  },

  // Swaps only the style prefix and the icon name class, so modifiers, other
  // classes and the inline size and colour stay as they are.
  applyIcon(icon, iconStyle, iconName) {
    const keptClasses = Array.from(icon.classList).filter((className) => {
      return !this.iconPrefixClasses.includes(className) && !this.isIconNameClass(className)
    })

    icon.className = [iconStyle, `fa-${iconName}`, ...keptClasses].join(" ")
  },

  acceptIconEdit(e) {
    e.preventDefault()

    this.hidePopup()
  },

  cancelIconEdit(e) {
    e.preventDefault()

    this.revertAndClose()
  },

  handlePopupKeydown(e) {
    if (e.key !== "Escape") return

    e.preventDefault()

    // The first Escape clears a search, the next one closes the picker
    if (e.target === this.getSearchInput() && e.target.value) {
      this.resetSearch()

      return
    }

    this.revertAndClose()
  },

  revertAndClose() {
    if (!this.currentIcon) return

    this.currentIcon.className = this.originalClassName
    this.hidePopup()
  },

  hidePopup() {
    App.Studio.ContentBlocks.SimpleEditMode.EditPopup.hide(this.getPopup())
    this.currentIcon = null
    this.originalClassName = null
  }
}
