(function() {
  "use strict";

  const TAG_NAME = "dropdown-select-menu";

  class DropdownSelectMenuElement extends HTMLElement {
    connectedCallback() {
      if (this.rendered) return;
      if (this.querySelector(".dropdown-select-container")) {
        this.markRendered();
        return;
      }

      if (this.ownerDocument.readyState === "loading") {
        this.renderWhenParsed();
        return;
      }

      this.renderNow();
    }

    renderWhenParsed() {
      const onReady = () => {
        if (this.rendered) return;

        this.renderNow();
      };

      document.addEventListener("DOMContentLoaded", onReady, { once: true });
    }

    renderNow() {
      this.render();
      this.markRendered();
    }

    markRendered() {
      this.rendered = true;
      this.classList.add("-rendered");
    }

    render() {
      const optionSpecs = this.readOptionSpecs();
      const config = {
        name: this.getAttribute("name") || "",
        title: this.getAttribute("title") || "",
        itemCssClass: this.getAttribute("item-css-class") || "",
        containerCssClass: this.getAttribute("container-css-class") || "",
        toggleTabindex: this.getAttribute("toggle-tabindex"),
        selectedText: this.resolveSelectedText(optionSpecs),
        optionSpecs: optionSpecs
      };

      const container = this.buildContainer(config);

      this.innerHTML = "";
      this.appendChild(container);
    }

    readOptionSpecs() {
      const specs = [];
      const children = Array.prototype.slice.call(this.children);

      children.forEach((child) => {
        if (child.tagName === "OPTION") {
          specs.push({
            type: "data",
            label: child.textContent.trim(),
            href: child.getAttribute("href"),
            selected: child.hasAttribute("selected"),
            className: child.getAttribute("class") || "",
            dataAttributes: this.extractDataAttributes(child)
          });
        } else {
          specs.push({
            type: "raw",
            node: child.cloneNode(true),
            label: child.textContent.trim(),
            selected: child.hasAttribute("selected")
          });
        }
      });

      return specs;
    }

    resolveSelectedText(optionSpecs) {
      const explicit = this.getAttribute("selected");

      if (explicit !== null) return explicit;

      const selectedSpec = optionSpecs.filter((spec) => spec.selected)[0];

      if (selectedSpec) return selectedSpec.label;

      const firstSpec = optionSpecs[0];

      return firstSpec ? firstSpec.label : "";
    }

    buildContainer(config) {
      const container = document.createElement("div");

      container.className = this.buildContainerClassName(config.containerCssClass);
      container.setAttribute("data-name", config.name);
      container.appendChild(this.buildToggle(config));
      container.appendChild(this.buildList(config));

      return container;
    }

    buildContainerClassName(containerCssClass) {
      const classes = ["dropdown-select-container", "js-dropdown-select-menu"];

      if (containerCssClass.length > 0) {
        classes.push(containerCssClass);
      }

      return classes.join(" ");
    }

    buildToggle(config) {
      const toggle = document.createElement("button");

      toggle.type = "button";
      toggle.className = "dropdown-select-menu-toggle js-dropdown-select-menu-toggle click-dropdown";
      toggle.setAttribute("aria-haspopup", "listbox");
      toggle.setAttribute("aria-expanded", "false");
      toggle.setAttribute("aria-label", config.title);
      toggle.textContent = config.selectedText;

      if (config.toggleTabindex !== null) {
        toggle.setAttribute("tabindex", config.toggleTabindex);
      }

      return toggle;
    }

    buildList(config) {
      const list = document.createElement("ul");

      list.className = "dropdown-select-menu--list";
      list.setAttribute("role", "listbox");
      list.setAttribute("aria-label", config.title);
      list.setAttribute("tabindex", "-1");

      config.optionSpecs.forEach((spec, index) => {
        list.appendChild(this.buildItem(spec, index, config.itemCssClass));
      });

      return list;
    }

    buildItem(spec, index, itemCssClass) {
      const item = document.createElement("li");

      item.className = this.buildItemClassName(spec, itemCssClass);
      item.setAttribute("role", "option");
      item.setAttribute("tabindex", "-1");
      item.setAttribute("data-index", index);

      this.applyDataAttributes(item, spec);
      this.fillItemContent(item, spec);

      return item;
    }

    buildItemClassName(spec, itemCssClass) {
      const classes = ["js-dropdown-select-menu-item", "dropdown-select-menu-item"];

      if (itemCssClass.length > 0) {
        classes.push(itemCssClass);
      }

      if (spec.type === "data" && spec.className.length > 0) {
        classes.push(spec.className);
      }

      return classes.join(" ");
    }

    applyDataAttributes(item, spec) {
      if (spec.type !== "data") return;

      Object.keys(spec.dataAttributes).forEach((key) => {
        item.setAttribute(key, spec.dataAttributes[key]);
      });
    }

    fillItemContent(item, spec) {
      if (spec.type === "raw") {
        item.appendChild(spec.node);
        return;
      }

      if (spec.href) {
        const link = document.createElement("a");

        link.href = spec.href;
        link.textContent = spec.label;
        item.appendChild(link);
        return;
      }

      item.textContent = spec.label;
    }

    extractDataAttributes(element) {
      const result = {};

      Array.prototype.forEach.call(element.attributes, (attr) => {
        if (attr.name.indexOf("data-") === 0) {
          result[attr.name] = attr.value;
        }
      });

      return result;
    }
  }

  if (!customElements.get(TAG_NAME)) {
    customElements.define(TAG_NAME, DropdownSelectMenuElement);
  }

  App.DropdownSelectMenuElement = DropdownSelectMenuElement;
}).call(this);
