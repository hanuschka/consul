(function() {
  "use strict";

  let inlinePopupIdCounter = 0;

  const SUPPORTS_POPOVER = HTMLElement.prototype.hasOwnProperty("showPopover");
  const SUPPORTS_ANCHOR = window.CSS && CSS.supports("anchor-name: --inline-popup-probe");
  const VIEWPORT_MARGIN = 8;

  // <inline-popup> turns its first non-template child (the trigger, a <button>)
  // into a click-to-open popover whose body is cloned from an inline <template>.
  // Built on the native Popover API (top layer, light-dismiss, Escape) and CSS
  // anchor positioning, with a fixed-position fallback for older browsers.
  //
  // Attributes:
  //   placement  "top" (default) | "bottom"
  //   align      "start" (default) | "end" | "center"
  //   dismiss    "auto" (default — closes on outside click + Escape) |
  //              "manual" (stays open on outside click; Escape, the
  //              trigger and [data-inline-popup-close] still close it)
  //
  // Public methods: open(), close(), toggle().
  // Any element with [data-inline-popup-close] inside the body closes the popup.
  // Emits bubbling "inline-popup:open" / "inline-popup:close" events.
  class InlinePopup extends HTMLElement {
    connectedCallback() {
      if (this.body) return

      if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", this.setup.bind(this), { once: true })
      } else {
        this.setup()
      }
    }

    disconnectedCallback() {
      this.unbindReposition()
      this.unbindFallbackDismiss()
      this.unbindManualEscape()
    }

    setup() {
      this.trigger = this.findTrigger()
      const template = this.querySelector(":scope > template")

      if (!this.trigger || !template) return

      this.placement = this.getAttribute("placement") || "top"
      this.align = this.getAttribute("align") || "start"
      this.lightDismiss = (this.getAttribute("dismiss") || "auto") !== "manual"

      this.buildBody(template)
      this.bindEvents()
    }

    findTrigger() {
      return Array.from(this.children).find((child) => child.tagName !== "TEMPLATE")
    }

    buildBody(template) {
      const body = document.createElement("div")

      inlinePopupIdCounter += 1
      body.id = `inline-popup-${inlinePopupIdCounter}`
      body.className = "inline-popup--body"
      body.setAttribute("role", "dialog")

      if (SUPPORTS_POPOVER) {
        body.setAttribute("popover", this.lightDismiss ? "auto" : "manual")
      }

      body.appendChild(template.content.cloneNode(true))
      template.remove()

      this.appendChild(body)
      this.body = body

      if (SUPPORTS_POPOVER) {
        this.trigger.setAttribute("popovertarget", body.id)
      }

      if (SUPPORTS_ANCHOR) {
        this.applyAnchorPositioning()
      }
    }

    applyAnchorPositioning() {
      const anchorName = `--inline-popup-anchor-${inlinePopupIdCounter}`

      this.trigger.style.setProperty("anchor-name", anchorName)
      this.body.style.setProperty("position-anchor", anchorName)
      this.body.style.setProperty("position-area", this.positionArea())
      this.body.style.setProperty("position-try-fallbacks", "flip-block, flip-inline")
    }

    positionArea() {
      const block = this.placement === "bottom" ? "bottom" : "top"

      if (this.align === "center") return block

      const inline = this.align === "end" ? "span-left" : "span-right"

      return `${block} ${inline}`
    }

    bindEvents() {
      this.body.addEventListener("click", this.handleBodyClick.bind(this))

      if (SUPPORTS_POPOVER) {
        this.body.addEventListener("toggle", this.handleToggle.bind(this))
      } else {
        this.trigger.addEventListener("click", this.toggle.bind(this))
      }
    }

    handleBodyClick(event) {
      const closer = event.target.closest("[data-inline-popup-close]")

      if (closer) this.close()
    }

    handleToggle(event) {
      if (event.newState === "open") {
        this.dispatchEvent(new CustomEvent("inline-popup:open", { bubbles: true }))

        if (!this.lightDismiss) this.bindManualEscape()

        if (!SUPPORTS_ANCHOR) {
          this.positionWithRect()
          this.bindReposition()
        }

        return
      }

      this.unbindManualEscape()
      this.unbindReposition()
      this.dispatchEvent(new CustomEvent("inline-popup:close", { bubbles: true }))
    }

    open() {
      if (SUPPORTS_POPOVER) {
        if (!this.body.matches(":popover-open")) this.body.showPopover()

        return
      }

      this.body.classList.add("-visible")
      this.positionWithRect()
      this.bindReposition()
      this.bindFallbackDismiss()
      this.dispatchEvent(new CustomEvent("inline-popup:open", { bubbles: true }))
    }

    close() {
      if (SUPPORTS_POPOVER) {
        if (this.body.matches(":popover-open")) this.body.hidePopover()

        return
      }

      this.body.classList.remove("-visible")
      this.unbindReposition()
      this.unbindFallbackDismiss()
      this.dispatchEvent(new CustomEvent("inline-popup:close", { bubbles: true }))
    }

    toggle() {
      if (SUPPORTS_POPOVER) return

      if (this.body.classList.contains("-visible")) {
        this.close()
      } else {
        this.open()
      }
    }

    bindFallbackDismiss() {
      this.onEscape = this.handleEscape.bind(this)
      document.addEventListener("keydown", this.onEscape)

      if (!this.lightDismiss) return

      this.onOutsideClick = this.handleOutsideClick.bind(this)
      setTimeout(() => document.addEventListener("click", this.onOutsideClick), 0)
    }

    unbindFallbackDismiss() {
      if (this.onEscape) {
        document.removeEventListener("keydown", this.onEscape)
        this.onEscape = null
      }

      if (this.onOutsideClick) {
        document.removeEventListener("click", this.onOutsideClick)
        this.onOutsideClick = null
      }
    }

    bindManualEscape() {
      this.onManualEscape = this.handleEscape.bind(this)
      document.addEventListener("keydown", this.onManualEscape)
    }

    unbindManualEscape() {
      if (!this.onManualEscape) return

      document.removeEventListener("keydown", this.onManualEscape)
      this.onManualEscape = null
    }

    handleOutsideClick(event) {
      if (this.contains(event.target)) return

      this.close()
    }

    handleEscape(event) {
      if (event.key === "Escape") this.close()
    }

    bindReposition() {
      this.reposition = this.positionWithRect.bind(this)

      window.addEventListener("scroll", this.reposition, true)
      window.addEventListener("resize", this.reposition)
    }

    unbindReposition() {
      if (!this.reposition) return

      window.removeEventListener("scroll", this.reposition, true)
      window.removeEventListener("resize", this.reposition)
      this.reposition = null
    }

    positionWithRect() {
      const rect = this.trigger.getBoundingClientRect()
      const bodyRect = this.body.getBoundingClientRect()
      const above = this.placement !== "bottom"

      let top = above ? rect.top - bodyRect.height - VIEWPORT_MARGIN : rect.bottom + VIEWPORT_MARGIN
      let left = this.fallbackLeft(rect, bodyRect.width)

      left = Math.max(VIEWPORT_MARGIN, Math.min(left, window.innerWidth - bodyRect.width - VIEWPORT_MARGIN))
      top = Math.max(VIEWPORT_MARGIN, top)

      Object.assign(this.body.style, {
        position: "fixed",
        top: `${top}px`,
        left: `${left}px`,
        margin: "0"
      })
    }

    fallbackLeft(rect, bodyWidth) {
      if (this.align === "end") return rect.right - bodyWidth
      if (this.align === "center") return rect.left + (rect.width - bodyWidth) / 2

      return rect.left
    }
  }

  customElements.define("inline-popup", InlinePopup);
}).call(this);
