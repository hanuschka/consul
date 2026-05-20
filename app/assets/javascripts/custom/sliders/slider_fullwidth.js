(function() {
  "use strict";

  App.SliderFullwidth = App.HorizontalSlider.create({
    rootSelector: ".js-slider-fullwidth",
    viewportSelector: ".js-slider-fullwidth-viewport",
    slideSelector: ".js-slider-fullwidth-slide",
    dotsClass: "js-slider-fullwidth-dots",
    initAttr: "data-slider-fullwidth-init",
    galleryPrefix: "sf-",
    scrollBehavior: "smooth",
    dotsPlacement: "viewport-parent",
    dotsContainerStyle: "position: absolute; bottom: 14px; right: 22px; display: flex; flex-wrap: wrap; align-items: center; z-index: 20; margin: 0; padding: 0;",

    dotBuilder(index) {
      const btn = document.createElement("button");
      btn.type = "button";
      btn.setAttribute("aria-label", "Slide " + (index + 1));
      btn.style.cssText = "display: flex; align-items: center; justify-content: center; min-width: 44px; min-height: 44px; padding: 0; background: transparent; border: 0; cursor: pointer;";

      const dot = document.createElement("span");
      dot.style.cssText = "display: block; width: 8px; height: 8px; border-radius: 50%; background: rgba(255,255,255,0.4); border: 1px solid rgba(255,255,255,0.5); transition: background 0.2s, border-color 0.2s;";
      btn.appendChild(dot);

      return {
        element: btn,
        setActive(active) {
          dot.style.background = active ? "#ffffff" : "rgba(255,255,255,0.4)";
          dot.style.borderColor = active ? "rgba(255,255,255,0.9)" : "rgba(255,255,255,0.5)";
        }
      };
    }
  });
}).call(this);
