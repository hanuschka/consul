(function() {
  "use strict";


  // Admin-Topbar Color Picker — sets a color setting via PATCH endpoint.
  // Generic: each picker decides which CSS custom property to drive and which
  // (optional) server-rendered <style> element to remove on reset, via the
  // `data-css-variable` and `data-style-element-id` attributes on the picker.
  // - `input` event: live preview (sets the CSS variable on :root) + debounced PATCH
  // - Reset button: clears color, removes inline CSS variable, removes the
  //   configured server-rendered <style> block on success (if any),
  //   PATCH `{ color: "" }`. Disabled while a request is in flight.
  // Defaults preserve the original brand-color behavior when no data attrs are
  // set (cssVariable defaults to "--brand-color", styleElementId defaults to
  // "js-brand-color-styles").
  App.Studio.Projekt.PageBrandColorPicker = {
    DEBOUNCE_MS: 500,
    SAVED_FEEDBACK_MS: 1000,
    HEX_RE: /^#[0-9a-f]{6}$/i,

    initialize: function() {
      var pickers = document.querySelectorAll(".js-admin-topbar-color-picker");
      if (!pickers.length) return;

      pickers.forEach(function(picker) {
        App.Studio.Projekt.PageBrandColorPicker.bindPicker(picker);
      });
    },

    bindPicker: function(picker) {
      if (picker.dataset.colorPickerBound === "true") return;
      picker.dataset.colorPickerBound = "true";

      var input = picker.querySelector(".js-admin-topbar-color-picker-input");
      var resetBtn = picker.querySelector(".js-admin-topbar-color-picker-reset");
      if (!input) return;

      var debouncedSave = App.Studio.Projekt.PageBrandColorPicker.debounce(function(value) {
        App.Studio.Projekt.PageBrandColorPicker.saveColor(picker, value);
      }, App.Studio.Projekt.PageBrandColorPicker.DEBOUNCE_MS);

      // Single `input` listener: live preview is immediate, save is debounced.
      // Firefox emits `change` like `input` while dragging, so we don't bind
      // a separate `change` handler — avoids a flood of PATCH requests.
      input.addEventListener("input", function(event) {
        var value = event.target.value;
        App.Studio.Projekt.PageBrandColorPicker.applyLivePreview(picker, value);
        debouncedSave(value);
      });

      if (resetBtn) {
        resetBtn.addEventListener("click", function(event) {
          event.preventDefault();
          if (resetBtn.disabled) return;
          resetBtn.disabled = true;

          App.Studio.Projekt.PageBrandColorPicker.handleReset(picker).finally(function() {
            resetBtn.disabled = false;
          });
        });
      }
    },

    applyLivePreview: function(picker, value) {
      var cssVariable = (picker && picker.dataset.cssVariable) || "--brand-color";
      if (!value) {
        document.documentElement.style.removeProperty(cssVariable);
        return;
      }
      document.documentElement.style.setProperty(cssVariable, value);
    },

    handleReset: function(picker) {
      var input = picker.querySelector(".js-admin-topbar-color-picker-input");
      if (!input) return Promise.resolve();

      var cssVariable = picker.dataset.cssVariable || "--brand-color";

      // Drop the live inline preview so the cascade can fall back to the
      // global default once the server-rendered <style> is removed
      // (which happens in saveColor's success branch — if a style element
      // ID is configured for this picker).
      document.documentElement.style.removeProperty(cssVariable);

      // Reflect the fallback in the swatch immediately. The fallback is the
      // global Setting['brand_color'] passed via data attribute — no hardcoded
      // hex, no need to read computed style (which would return the still-
      // present project-color from the server <style> block at this point).
      var fallback = picker.dataset.fallbackColor;
      if (fallback && App.Studio.Projekt.PageBrandColorPicker.HEX_RE.test(fallback)) {
        input.value = fallback;
      }

      return App.Studio.Projekt.PageBrandColorPicker.saveColor(picker, "");
    },

    saveColor: function(picker, value) {
      var url = picker.dataset.url;
      if (!url) return Promise.resolve();

      var csrfMeta = document.querySelector("meta[name=csrf-token]");
      var csrfToken = csrfMeta ? csrfMeta.getAttribute("content") : "";

      App.Studio.Projekt.PageBrandColorPicker.setStatus(picker, "saving");

      return fetch(url, {
        method: "PATCH",
        credentials: "same-origin",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken,
          "Accept": "application/json"
        },
        body: JSON.stringify({ color: value })
      })
        .then(function(response) {
          if (!response.ok) {
            throw new Error("Request failed with status " + response.status);
          }
          return response.json();
        })
        .then(function(data) {
          var savedColor = (data && typeof data.color !== "undefined") ? data.color : value;
          picker.dataset.currentColor = savedColor || "";

          // When the saved color is empty (reset), the server-rendered
          // <style> block for this picker is still in the DOM and would keep
          // applying the old color until reload. Remove it so the theme
          // default takes over immediately. The element ID is configurable
          // via `data-style-element-id` (default: "js-brand-color-styles").
          // An empty string explicitly opts out (e.g. when there is no
          // matching server-rendered <style> block to clean up).
          if (!savedColor) {
            var styleElementId = picker.dataset.styleElementId;
            if (typeof styleElementId === "undefined") {
              styleElementId = "js-brand-color-styles";
            }
            if (styleElementId) {
              var styleEl = document.getElementById(styleElementId);
              if (styleEl) styleEl.remove();
            }
          }

          App.Studio.Projekt.PageBrandColorPicker.setStatus(picker, "ok");
          window.setTimeout(function() {
            App.Studio.Projekt.PageBrandColorPicker.setStatus(picker, "");
          }, App.Studio.Projekt.PageBrandColorPicker.SAVED_FEEDBACK_MS);
        })
        .catch(function() {
          // Revert live preview to last known saved color
          var cssVariable = picker.dataset.cssVariable || "--brand-color";
          var fallback = picker.dataset.currentColor;
          if (fallback) {
            document.documentElement.style.setProperty(cssVariable, fallback);
            var input = picker.querySelector(".js-admin-topbar-color-picker-input");
            if (input) input.value = fallback;
          } else {
            document.documentElement.style.removeProperty(cssVariable);
          }
          App.Studio.Projekt.PageBrandColorPicker.setStatus(picker, "error");
          window.setTimeout(function() {
            App.Studio.Projekt.PageBrandColorPicker.setStatus(picker, "");
          }, App.Studio.Projekt.PageBrandColorPicker.SAVED_FEEDBACK_MS * 2);
        });
    },

    setStatus: function(picker, state) {
      if (!state) {
        delete picker.dataset.savedState;
      } else {
        picker.dataset.savedState = state;
      }

      var statusEl = picker.querySelector(".js-admin-topbar-color-picker-status");
      if (!statusEl) return;

      var text = "";
      if (state === "saving") {
        text = picker.dataset.i18nSaving || "";
      } else if (state === "ok") {
        text = picker.dataset.i18nSaved || "";
      } else if (state === "error") {
        text = picker.dataset.i18nError || "";
      }
      statusEl.textContent = text;
    },

    debounce: function(fn, wait) {
      var timer = null;
      return function() {
        var context = this;
        var args = arguments;
        if (timer) clearTimeout(timer);
        timer = setTimeout(function() {
          fn.apply(context, args);
        }, wait);
      };
    }
  };

  // Self-init: the pickers render on welcome/custom pages (non-projekt), so
  // initialization can't ride on App.Studio.Projekt.initialize(). Re-running
  // on turbolinks:load is safe — bindPicker guards per element.
  if (
    document.readyState === "complete"
    || document.readyState === "loaded"
    || document.readyState === "interactive"
  ) {
    App.Studio.Projekt.PageBrandColorPicker.initialize();
  }
  else {
    document.addEventListener("DOMContentLoaded", function() {
      App.Studio.Projekt.PageBrandColorPicker.initialize();
    });
  }

  document.addEventListener("turbolinks:load", function() {
    App.Studio.Projekt.PageBrandColorPicker.initialize();
  });
}).call(this);
