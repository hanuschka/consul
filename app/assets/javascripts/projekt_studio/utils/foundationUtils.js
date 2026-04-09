ProjektStudio.utils.removeFoundationIds = function(element) {
  element.querySelectorAll('[data-accordion]').forEach((accordion) => {
    accordion.setAttribute('data-accordion', '');

    ProjektStudio.utils.removeChildHtmlAttributes(
      accordion,
      ["id", "aria-labelledby", "aria-controls"]
    );
  });
}

ProjektStudio.utils.resetFoundationAccordionStateFor = function(accordionRoot) {
  accordionRoot.querySelectorAll(".accordion-item.is-active").forEach((element) => {
    element.classList.remove('is-active')
  })
  accordionRoot.querySelectorAll(".accordion-content").forEach((element) => {
    element.style.display = 'none';
    element.ariaHidden = "true";
  })
  accordionRoot.querySelectorAll(".accordion-title").forEach((element) => {
    element.ariaSelected = "false";
  })
}
