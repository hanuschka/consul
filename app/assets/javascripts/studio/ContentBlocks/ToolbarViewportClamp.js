App.Studio.ContentBlocks.ToolbarViewportClamp = {
  viewportMargin: 12,
  shiftProperty: "--studio-toolbar-viewport-shift",
  compactWrapperSelector: ".custom-content-block-wrapper.-compact-mode",
  watchedWrappers: new Set(),
  resizeObserver: null,

  initialize() {
    this.resizeObserver = new ResizeObserver(this.handleToolbarResize.bind(this))

    $(document).on(
      "mouseenter focusin",
      this.compactWrapperSelector,
      this.handleWrapperReached.bind(this)
    )

    window.addEventListener(
      "resize",
      App.Studio.utils.debounce(this.clampWatchedWrappers.bind(this), 150)
    )
  },

  handleWrapperReached(e) {
    const wrapper = e.currentTarget

    if (this.watchedWrappers.has(wrapper)) return

    this.forgetDetachedWrappers()
    this.watchedWrappers.add(wrapper)
    this.getToolbars(wrapper).forEach((toolbar) => this.resizeObserver.observe(toolbar))
  },

  handleToolbarResize(entries) {
    const wrappers = new Set(
      entries.map((entry) => entry.target.closest(this.compactWrapperSelector))
    )

    this.clamp(Array.from(wrappers).filter((wrapper) => wrapper && wrapper.isConnected))
  },

  clampWatchedWrappers() {
    this.forgetDetachedWrappers()
    this.clamp(Array.from(this.watchedWrappers))
  },

  forgetDetachedWrappers() {
    this.watchedWrappers.forEach((wrapper) => {
      if (wrapper.isConnected) return

      this.getToolbars(wrapper).forEach((toolbar) => this.resizeObserver.unobserve(toolbar))
      this.watchedWrappers.delete(wrapper)
    })
  },

  clamp(wrappers) {
    wrappers.forEach((wrapper) => wrapper.style.removeProperty(this.shiftProperty))

    const viewportRight = document.documentElement.clientWidth - this.viewportMargin
    const shifts = wrappers.map((wrapper) => {
      const toolbarBounds = this.getToolbarBounds(wrapper)

      if (!toolbarBounds) return 0

      const overflow = toolbarBounds.right - viewportRight
      const room = toolbarBounds.left - this.viewportMargin

      return Math.min(overflow, room)
    })

    wrappers.forEach((wrapper, index) => {
      if (shifts[index] <= 0) return

      wrapper.style.setProperty(this.shiftProperty, `${-shifts[index]}px`)
    })
  },

  getToolbarBounds(wrapper) {
    const rects = this.getToolbars(wrapper)
      .map((toolbar) => toolbar.getBoundingClientRect())
      .filter((rect) => rect.width > 0)

    if (rects.length === 0) return null

    return {
      left: Math.min(...rects.map((rect) => rect.left)),
      right: Math.max(...rects.map((rect) => rect.right))
    }
  },

  getToolbars(wrapper) {
    return Array.from(
      wrapper.querySelectorAll(".custom-content-block--toolbar-row > .custom-content-block--toolbar")
    )
  }
};
