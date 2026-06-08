(function() {
  "use strict";

  let tooltipIdCounter = 0;

  const SUPPORTS_POPOVER = HTMLElement.prototype.hasOwnProperty("showPopover");
  const SUPPORTS_ANCHOR = window.CSS && CSS.supports("anchor-name: --rich-tooltip-probe");
  const DEFAULT_HIDE_DELAY = 150;
  const DEFAULT_SHOW_DELAY = 600;

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

      this.showDelay = this.parseDelay("delay", DEFAULT_SHOW_DELAY)
      this.hideDelay = this.parseDelay("hide-delay", DEFAULT_HIDE_DELAY)
      this.placement = this.getAttribute("placement") || "top"

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
      this.trigger.addEventListener("focusin", this.scheduleShow.bind(this))
      this.trigger.addEventListener("focusout", this.scheduleHide.bind(this))
      this.tooltipBody.addEventListener("mouseenter", this.cancelHide.bind(this))
      this.addEventListener("mouseleave", this.scheduleHide.bind(this))
      this.addEventListener("keydown", this.handleKeydown.bind(this))
    }

    scheduleShow() {
      clearTimeout(this.hideTimeout)
      this.showTimeout = setTimeout(this.show.bind(this), this.showDelay)
    }

    scheduleHide() {
      clearTimeout(this.showTimeout)
      this.hideTimeout = setTimeout(this.hide.bind(this), this.hideDelay)
    }

    cancelHide() {
      clearTimeout(this.hideTimeout)
    }

    show() {
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
