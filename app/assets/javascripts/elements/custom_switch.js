(function() {
  "use strict";

  // <custom-switch> renders a shared, CSS-driven toggle switch (track + thumb +
  // optional label/description) around a real checkbox input in the light DOM,
  // so form submission, `.checked` reads and framework hooks (Stimulus targets,
  // js- classes) keep working. The host element is display:contents; a single
  // inner <label class="custom-switch"> is the actual control, which also makes
  // the whole switch clickable. Styles live in
  // cross_pack/components/_custom_switch.scss and are shared across both
  // stylesheet packs.
  //
  // Attributes (all optional):
  //   label         visible label text
  //   description   secondary hint text below the label
  //   name          form field name (adds a hidden "0" companion like Rails
  //                 check_box_tag so an unchecked box still submits)
  //   value         submitted value when checked (default "1")
  //   checked       initial checked state (boolean attribute)
  //   disabled      disabled state (boolean attribute)
  //   theme         "dark" for the light-on-dark studio topbar surface
  //   row           card-style full-width row layout (boolean attribute)
  //   input-id      id applied to the inner checkbox
  //   input-class   extra css classes for the inner checkbox (e.g. js- hooks)
  //   control-class extra css classes for the inner <label> (e.g. topbar chrome)
  //   control-title native title/tooltip for the inner <label>
  //   data-*        forwarded onto the inner checkbox (Stimulus targets etc.)
  class CustomSwitch extends HTMLElement {
    connectedCallback() {
      if (this.rendered) return

      this.render();
      this.rendered = true;
    }

    get checked() {
      return this.input ? this.input.checked : this.hasAttribute("checked");
    }

    set checked(value) {
      if (this.input) this.input.checked = !!value;
    }

    render() {
      const forwardedData = this.collectForwardedData();
      const control = this.buildControl();

      this.appendHiddenCompanion(control);
      this.input = this.buildInput(forwardedData);
      control.appendChild(this.input);
      control.appendChild(this.buildTrack());

      const text = this.buildText();
      if (text) control.appendChild(text);

      this.appendChild(control);
    }

    buildControl() {
      const control = document.createElement("label");
      control.className = "custom-switch";

      if (this.hasAttribute("row")) control.classList.add("-row");
      if (this.getAttribute("theme") === "dark") control.classList.add("-dark");

      const controlClass = this.getAttribute("control-class");
      if (controlClass) control.className += ` ${controlClass}`;

      const title = this.getAttribute("control-title");
      if (title) control.title = title;

      return control;
    }

    appendHiddenCompanion(control) {
      const name = this.getAttribute("name");
      if (!name) return

      const hidden = document.createElement("input");
      hidden.type = "hidden";
      hidden.name = name;
      hidden.value = "0";
      control.appendChild(hidden);
    }

    buildInput(forwardedData) {
      const input = document.createElement("input");
      input.type = "checkbox";
      input.className = "custom-switch--input";

      const name = this.getAttribute("name");
      if (name) input.name = name;

      input.value = this.getAttribute("value") || "1";

      if (this.hasAttribute("checked")) input.checked = true;
      if (this.hasAttribute("disabled")) input.disabled = true;

      const inputId = this.getAttribute("input-id");
      if (inputId) input.id = inputId;

      const inputClass = this.getAttribute("input-class");
      if (inputClass) input.className += ` ${inputClass}`;

      Object.keys(forwardedData).forEach((key) => {
        input.setAttribute(`data-${key}`, forwardedData[key]);
      });

      return input;
    }

    buildTrack() {
      const track = document.createElement("span");
      track.className = "custom-switch--track";
      track.setAttribute("aria-hidden", "true");

      const thumb = document.createElement("span");
      thumb.className = "custom-switch--thumb";
      track.appendChild(thumb);

      return track;
    }

    buildText() {
      const label = this.getAttribute("label");
      const description = this.getAttribute("description");

      if (!label && !description) return null

      const text = document.createElement("span");
      text.className = "custom-switch--text";

      if (label) {
        const labelEl = document.createElement("span");
        labelEl.className = "custom-switch--label";
        labelEl.textContent = label;
        text.appendChild(labelEl);
      }

      if (description) {
        const descEl = document.createElement("span");
        descEl.className = "custom-switch--description";
        descEl.textContent = description;
        text.appendChild(descEl);
      }

      return text;
    }

    // Attributes prefixed with "data-" are moved onto the inner checkbox so
    // Stimulus targets/actions and other data hooks resolve to the real input.
    collectForwardedData() {
      const forwarded = {};

      Array.from(this.attributes).forEach((attr) => {
        if (attr.name.indexOf("data-") !== 0) return

        forwarded[attr.name.slice(5)] = attr.value;
        this.removeAttribute(attr.name);
      });

      return forwarded;
    }
  }

  customElements.define("custom-switch", CustomSwitch);
}).call(this);
