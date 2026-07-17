// Narrow Foundation reset for content that STAYS in the same document
// (template insert, AI content, in-place widget re-init). Only neutralizes
// accordions — the one widget Foundation cannot re-initialize twice in the
// same document with its auto-generated ids. Author ids elsewhere (e.g.
// anchor targets for in-page "jump to section" links) are intentional and
// MUST survive, so they are left untouched. For content that leaves the
// document, use cleanContentForClipboard instead.
App.Studio.utils.removeFoundationIds = function(element) {
  element.querySelectorAll("[data-accordion]").forEach((accordion) => {
    accordion.setAttribute("data-accordion", "");

    App.Studio.utils.removeChildHtmlAttributes(
      accordion,
      ["id", "aria-labelledby", "aria-controls"]
    );
  });
}

App.Studio.utils.resetFoundationAccordionStateFor = function(accordionRoot) {
  accordionRoot.querySelectorAll(".accordion-item.is-active").forEach((element) => {
    element.classList.remove("is-active");
  });

  accordionRoot.querySelectorAll(".accordion-content").forEach((element) => {
    element.style.display = "none";
    element.ariaHidden = "true";
  });

  accordionRoot.querySelectorAll(".accordion-title").forEach((element) => {
    element.ariaSelected = "false";
  });
}

// Aggressive cleanup for content that LEAVES the document via the clipboard.
// The paste target is unknown and may already hold the same Foundation/author
// ids, so EVERY id is stripped to avoid duplicate-id collisions (invalid DOM,
// wrong getElementById, anchor links jumping to the wrong node at the target),
// and Orbit/resize plugin markers bound to the old initialized instance are
// reset so Foundation re-initializes cleanly on paste. This is why the extra
// stripping lives here and not in removeFoundationIds (which the in-document
// re-init paths share): same input, but the document boundary flips the safe
// assumption from "ids are unique" to "ids may already exist". Delegates the
// accordion reset to removeFoundationIds.
App.Studio.utils.cleanContentForClipboard = function(element) {
  element.querySelectorAll("*").forEach((node) => {
    if (node.hasAttribute("data-orbit")) {
      node.setAttribute("data-orbit", "");
    }

    node.removeAttribute("data-resize");
    node.removeAttribute("id");
  });

  App.Studio.utils.removeFoundationIds(element);
}
