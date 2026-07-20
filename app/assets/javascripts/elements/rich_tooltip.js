(function() {
  "use strict";

  let tooltipIdCounter = 0;

  const SUPPORTS_POPOVER = HTMLElement.prototype.hasOwnProperty("showPopover");
  const SUPPORTS_ANCHOR = window.CSS && CSS.supports("anchor-name: --rich-tooltip-probe");
  const DEFAULT_HIDE_DELAY = 150;
  const DEFAULT_SHOW_DELAY = 600;
  const INSTANT_SHOW_DELAY = 100;
  const INSTANT_HIDE_DELAY = 80;

  // <rich-tooltip> wraps a trigger (first non-template child) + a <template>
  // body. Attributes:
  //   placement     "top" (default) | "right"
  //   delay         show delay in ms (default 600, 0 allowed)
  //   hide-delay    hide delay in ms (default 150, 0 allowed)
  //   size          "default" | "big" | "no-paddings" (body padding preset)
  //   shadow        "default" | "heavy" (body drop-shadow strength)
  //   trigger-only  show only while the trigger is hovered (body ignores
  //                 pointer events)
  //   hover-only    show on pointer hover only; do not show on keyboard
  //                 focus / focusout
  //   instant       near-instant: forces show delay to 100ms and hide delay
  //                 to 80ms, and disables the body show/hide transition +
  //                 animation
  //   template-id   use an external <template> by id instead of an inline one
  //   body-class    extra css class(es) added to the tooltip body element
  //   disabled      never show while present; checked at show time, so it can
  //                 be toggled live from JS
  class RichTooltip extends HTMLElement {
    connectedCallback() {
      if (this.tooltipBody) return

      if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", this.setup.bind(this), { once: true })
      } else {
        this.setup()
      }
    }

    disconnectedCallback() {
      clearTimeout(this.showTimeout)
      clearTimeout(this.hideTimeout)
    }

    setup() {
      this.trigger = this.findTrigger()
      const template = this.findTemplate()

      if (!this.trigger || !template) return

      this.instant = this.hasAttribute("instant")
      this.showDelay = this.instant ? INSTANT_SHOW_DELAY : this.parseDelay("delay", DEFAULT_SHOW_DELAY)
      this.hideDelay = this.instant ? INSTANT_HIDE_DELAY : this.parseDelay("hide-delay", DEFAULT_HIDE_DELAY)
      this.placement = this.getAttribute("placement") || "top"
      this.size = this.getAttribute("size") || "default"
      this.shadow = this.getAttribute("shadow") || "default"
      this.bodyClass = this.getAttribute("body-class") || ""
      this.triggerOnly = this.hasAttribute("trigger-only")
      this.hoverOnly = this.hasAttribute("hover-only")
      this.focusable = this.hasAttribute("focusable")

      this.buildTooltipBody(template)
      this.bindEvents()
    }

    parseDelay(name, fallback) {
      const value = parseInt(this.getAttribute(name), 10)

      return Number.isNaN(value) ? fallback : value
    }

    findTrigger() {
      return Array.from(this.children).find((child) => child.tagName !== "TEMPLATE")
    }

    findTemplate() {
      const inlineTemplate = this.querySelector(":scope > template")
      if (inlineTemplate) return inlineTemplate

      return document.getElementById(this.getAttribute("template-id"))
    }

    buildTooltipBody(template) {
      const body = document.createElement("div")

      tooltipIdCounter += 1
      body.id = `rich-tooltip-${tooltipIdCounter}`
      body.className = "rich-tooltip--body"
      body.setAttribute("role", "tooltip")

      if (this.size !== "default") {
        body.classList.add(`-${this.size}`)
      }

      if (this.shadow !== "default") {
        body.classList.add(`-shadow-${this.shadow}`)
      }

      const extraClasses = this.bodyClass.split(/\s+/).filter(Boolean)
      if (extraClasses.length) {
        body.classList.add(...extraClasses)
      }

      if (this.triggerOnly && !this.focusable) {
        body.style.pointerEvents = "none"
      }

      if (this.instant) {
        body.classList.add("-instant")
      }

      if (SUPPORTS_POPOVER) {
        body.setAttribute("popover", "hint")
      }

      body.appendChild(template.content.cloneNode(true))

      if (template.parentElement === this) {
        template.remove()
      }

      this.appendChild(body)
      this.trigger.setAttribute("aria-describedby", body.id)
      this.tooltipBody = body

      if (SUPPORTS_ANCHOR) {
        const anchorName = `--rich-tooltip-anchor-${tooltipIdCounter}`
        this.trigger.style.setProperty("anchor-name", anchorName)
        body.style.setProperty("position-anchor", anchorName)
        this.applyAnchorPlacement(body)
      }
    }

    applyAnchorPlacement(body) {
      if (this.placement !== "right") return

      body.style.setProperty("position-area", "inline-end")
      body.style.setProperty("position-try-fallbacks", "flip-inline")
      body.style.marginBlockEnd = "0"
      body.style.marginInlineStart = "8px"
    }

    bindEvents() {
      this.trigger.addEventListener("mouseenter", this.scheduleShow.bind(this))
      this.trigger.addEventListener("mouseleave", this.handleTriggerMouseleave.bind(this))
      this.trigger.addEventListener("pointerdown", this.suppressShow.bind(this))

      if (!this.hoverOnly) {
        this.trigger.addEventListener("focusin", this.handleFocusin.bind(this))
        this.trigger.addEventListener("focusout", this.scheduleHide.bind(this))
      }

      this.addEventListener("keydown", this.handleKeydown.bind(this))

      if (this.focusable) {
        this.tooltipBody.addEventListener("mouseenter", this.cancelHide.bind(this))
        this.addEventListener("mouseleave", this.scheduleHide.bind(this))
      } else if (this.triggerOnly) {
        this.trigger.addEventListener("mouseleave", this.scheduleHide.bind(this))
      } else {
        this.tooltipBody.addEventListener("mouseenter", this.cancelHide.bind(this))
        this.addEventListener("mouseleave", this.scheduleHide.bind(this))
      }
    }

    // Focus re-shows the tooltip only for keyboard-originated focus
    // (:focus-visible). A pointer click that focuses the trigger — or focus
    // restored to it after a modal/dialog it opened closes — must not pop the
    // tooltip back up over the action the user just took;
    // matches(":focus-visible") is false in both those pointer-driven cases.
    handleFocusin() {
      if (!this.focusIsVisible()) return

      this.scheduleShow()
    }

    focusIsVisible() {
      try {
        return this.trigger.matches(":focus-visible")
      } catch (error) {
        return true
      }
    }

    scheduleShow() {
      if (this.showSuppressed) return
      if (this.hasAttribute("disabled")) return

      clearTimeout(this.hideTimeout)
      clearTimeout(this.showTimeout)
      this.showTimeout = setTimeout(this.show.bind(this), this.showDelay)
    }

    // A click on the trigger suppresses the tooltip so it does not pop up over
    // the action the user just took (the trigger also gains focus on click,
    // which would otherwise re-trigger the focus show). Suppression lasts until
    // the pointer genuinely leaves the trigger; re-hovering arms it again.
    suppressShow() {
      this.showSuppressed = true
      this.hide()
    }

    // Re-arm only on a real move out of the trigger. A modal backdrop (or any
    // overlay) opening over the trigger fires a synthetic mouseleave while the
    // pointer is stationary — its coordinates are still inside the trigger box,
    // so ignore it; otherwise the tooltip would re-show when that overlay closes
    // and a matching synthetic mouseenter fires over the still-parked pointer.
    handleTriggerMouseleave(event) {
      if (this.pointerWithinTrigger(event)) return

      this.showSuppressed = false
    }

    pointerWithinTrigger(event) {
      const rect = this.trigger.getBoundingClientRect()

      return event.clientX >= rect.left && event.clientX <= rect.right &&
        event.clientY >= rect.top && event.clientY <= rect.bottom
    }

    scheduleHide() {
      clearTimeout(this.showTimeout)
      this.hideTimeout = setTimeout(this.hide.bind(this), this.hideDelay)
    }

    cancelHide() {
      clearTimeout(this.hideTimeout)
    }

    show() {
      if (this.trigger.querySelector(":popover-open")) return

      if (SUPPORTS_POPOVER) {
        this.tooltipBody.showPopover()
      } else {
        this.tooltipBody.classList.add("-visible")
      }

      if (!SUPPORTS_ANCHOR) {
        this.positionWithRect()
      }
    }

    hide() {
      clearTimeout(this.showTimeout)

      if (SUPPORTS_POPOVER && this.tooltipBody.matches(":popover-open")) {
        this.tooltipBody.hidePopover()
      }

      this.tooltipBody.classList.remove("-visible")
    }

    handleKeydown(e) {
      if (e.key !== "Escape") return

      clearTimeout(this.showTimeout)
      this.hide()
    }

    positionWithRect() {
      const rect = this.trigger.getBoundingClientRect()

      if (this.placement === "right") {
        Object.assign(this.tooltipBody.style, {
          position: "fixed",
          left: `${rect.right + 8}px`,
          top: `${rect.top + rect.height / 2}px`,
          transform: "translateY(-50%)"
        })

        return
      }

      Object.assign(this.tooltipBody.style, {
        position: "fixed",
        left: `${rect.left}px`,
        top: `${rect.top}px`,
        transform: "translateY(calc(-100% - 8px))"
      })
    }
  }

  customElements.define("rich-tooltip", RichTooltip);
}).call(this);
