ProjektStudio.utils.removeFoundationIds = function(element) {
  element.querySelectorAll("[data-accordion]").forEach((accordion) => {
    accordion.setAttribute("data-accordion", "");

    ProjektStudio.utils.removeChildHtmlAttributes(
      accordion,
      ["id", "aria-labelledby", "aria-controls"]
    );
  });
}

ProjektStudio.utils.cleanContentForClipboard = function(element) {
  element.querySelectorAll("*").forEach((node) => {
    if (node.hasAttribute("data-orbit")) {
      node.setAttribute("data-orbit", "");
    }

    node.removeAttribute("data-resize");
    node.removeAttribute("id");
  });

  ProjektStudio.utils.removeFoundationIds(element);
}
