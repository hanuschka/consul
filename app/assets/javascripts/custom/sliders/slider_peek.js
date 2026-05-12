(function() {
  "use strict";

  App.SliderPeek = App.HorizontalSlider.create({
    rootSelector: ".js-slider-peek",
    viewportSelector: ".js-slider-peek-viewport",
    slideSelector: ".js-slider-peek-slide",
    dotsClass: "js-slider-peek-dots",
    initAttr: "data-slider-peek-init",
    galleryPrefix: "sp-",
    scrollBehavior: "smooth",
    dotsPlacement: "root",
    dotsContainerStyle: "display: flex; justify-content: center; gap: 8px; margin-top: 16px;",

    dotBuilder(index) {
      const btn = document.createElement("button");
      btn.type = "button";
      btn.setAttribute("aria-label", "Slide " + (index + 1));
      btn.style.cssText = "width: 10px; height: 10px; padding: 0; border: 0; border-radius: 50%; background: rgba(0,0,0,0.2); cursor: pointer; transition: background 0.2s, transform 0.2s;";

      return {
        element: btn,
        setActive(active) {
          btn.style.background = active ? "var(--brand-color, #1779ba)" : "rgba(0,0,0,0.2)";
          btn.style.transform = active ? "scale(1.3)" : "scale(1)";
        }
      };
    }
  });
}).call(this);
