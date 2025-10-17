ProjektStudio.ContentBlockSimpleEdit.ListEdit = {
  listControlClass: "js-content-block--list-control",

  initialize() {
    this.initEventListeners()
    this.getContentBlockAndWrapper = ProjektStudio.ContentBlocks.getContentBlockAndWrapper.bind(ProjektStudio.ContentBlocks)
  },

  initEventListeners() {
    const $document = $(document);
    $document.on("click", ".js-projekt-content-block--add-item", this.addItem.bind(this))
    $document.on("click", ".js-projekt-content-block--delete-item", this.deleteItem.bind(this))
  },

  toggleListControls(contentBlock, enabled) {
    if (enabled) {
      contentBlock
        .querySelectorAll("ul")
        .forEach((ul) => {
          const foundationSlider = ul.closest(".orbit")

          if (foundationSlider) {
            this.addNewSliderItemButton(ul)
          } else {
            this.addNewItemButton(ul)
          }
        })

      contentBlock
        .querySelectorAll(`li:not(.${this.listControlClass})`)
        .forEach((li) => {
          this.addItemDeleteButton(li)
        })
    }
    else {
      contentBlock
        .querySelectorAll(`.${this.listControlClass}`)
        .forEach((e) => e.remove())
    }
  },

  addItemDeleteButton(li) {
    const buttonHTML = `
        <button class="content-block--item-delete-button js-projekt-content-block--delete-item ${this.listControlClass} -delete">
        <i class="fa fas fa-trash"></i>
       </button>
     `

    const buttonElement = ProjektStudio.utils.htmlToSingleDomElement(buttonHTML)

    const elementStyle = getComputedStyle(li);

    if (elementStyle.position === "static") {
      li.style.position = "relative"
    }
    li.appendChild(buttonElement);
  },

  addItem(e) {
    const wrapper = e.currentTarget.closest(`.${this.listControlClass}`)
    let ul = null;
    let ulParent;
    let lastLi;

    if (wrapper.dataset.outsideList === "true") {
      ulParent = wrapper.previousElementSibling;
      ul = ulParent.querySelector("ul");
      lastLi = ul.querySelector("li:last-child")
    }
    else {
      ul = e.currentTarget.closest("ul")
      lastLi = ul.querySelector(`li:nth-last-child(2):not(.${this.listControlClass})`)
    }

    const isSlider = ul.classList.contains("orbit-container")
    const isAccordion = ul.classList.contains("accordion")

    ProjektStudio.utils.resetFoundationAccordionStateFor(ul)
    const clonedLi = lastLi.cloneNode(true);

    ProjektStudio.utils.removeChildHtmlAttributes(
      clonedLi,
      ["id", "aria-labelledby", "aria-controls", "aria-expanded", "data-slide"]
    )

    // clonedLi.querySelectorAll("img").forEach((img) => {
    //   img.dataset.originalThumbHeight = ""
    // })

    const copyId = Date.now();

    let elementToReinitialize = isSlider ? ul.closest(".orbit") : ul;
    elementToReinitialize.id = '';

    let elementToReinitializeParent = elementToReinitialize.parentElement;
    elementToReinitialize.dataset.contentBlockListItemCopyId = copyId;

    if (isSlider || isAccordion) {
      elementToReinitialize.outerHTML = elementToReinitialize.outerHTML;
    }

    const newElementToReinitialize = elementToReinitializeParent.querySelector(`[data-content-block-list-item-copy-id="${copyId}"]`)
    newElementToReinitialize.removeAttribute("data-content-block-list-item-copy-id")

    const newUl = isSlider ? elementToReinitializeParent.querySelector('ul') : newElementToReinitialize;

    if (isSlider) {
      newUl.append(clonedLi);

      this.updateSliderItemAttributes(lastLi, clonedLi)
    }
    else {
      newUl.insertBefore(clonedLi, newUl.lastElementChild);
    }

    $(newElementToReinitialize).foundation()

    if (isAccordion) {
      const $accordionLinks = $(newElementToReinitialize).find('.accordion-title');
      $accordionLinks.off("keydown")
    }
  },

  updateSliderItemAttributes(lastLi, clonedLi) {
    const previousSlideNumber = Number.parseInt(lastLi.dataset.slide);
    const newSlideNumber = previousSlideNumber + 1;
    clonedLi.dataset.slide = newSlideNumber;

    this.addBulletToSlider(clonedLi.closest("ul"), newSlideNumber)

    const previousImg = lastLi.querySelector('img')
    const clonedImg = clonedLi.querySelector('img')

    clonedImg.setAttribute("src", previousImg.getAttribute("src").replace(`text=Slide-${previousSlideNumber + 1}`, `text=Slide-${newSlideNumber + 1}`))
    clonedLi.querySelector(".orbit-caption").innerHTML = `Slide ${newSlideNumber + 1}`;
  },

  deleteItem(e) {
    const deleteConfirmed = confirm("Möchten Sie das letzte Element wirklich aus der Liste löschen?")

    if (!deleteConfirmed) return;

    const li = e.currentTarget.closest("li")
    const ul = li.closest("ul")

    const isSlider = ul.classList.contains("orbit-container")

    if (isSlider) {
      const lastBullet = ul.closest(".orbit").querySelector(".orbit-bullets > button:last-child")
      if (lastBullet.classList.contains("is-active")) {
        lastBullet.previousElementSibling.click()
      }
      lastBullet.remove()
    }

    li.remove()
  },

  addBulletToSlider(ul, newSlideNumber) {
    const bulletsElement = ul.closest(".orbit").querySelector(".orbit-bullets")

    const newBulletHTML = `
      <button data-slide="${newSlideNumber}" class="">
        <span class="show-for-sr">
          Bild ${newSlideNumber}
        </span>
      </button>
    `

    const newBullet = ProjektStudio.utils.htmlToSingleDomElement(newBulletHTML)
    bulletsElement.append(newBullet)
  },

  addNewItemButton(ul) {
    const buttonWrapper = this.buildItemManagmentControls(ul, { elementType: "li", copyStyles: true})

    ul.appendChild(buttonWrapper);
  },

  addNewSliderItemButton(ul) {
    const buttonWrapper = this.buildItemManagmentControls(ul, { elementType: "div", copyStyles: false })

    const foundationSlider = ul.closest(".orbit")
    buttonWrapper.dataset.outsideList = true
    foundationSlider.after(buttonWrapper);
  },

  buildItemManagmentControls(ul, { elementType, copyStyles = false } ) {
    const buttonWrapper = document.createElement(elementType);
    buttonWrapper.className = `content-block--item-action-wrapper ${this.listControlClass}`;
    buttonWrapper.style.listStyle = "none";

    const lastLi = ul.querySelector("li:last-child")

    if (copyStyles && lastLi.classList.value !== "") {
      const gridPattern = /^(grid-[xy]|grid-(margin|padding)-[xy]|cell|column|columns|small-\d+|medium-\d+|large-\d+)$/;
      const filtered = Array.from(lastLi.classList).filter(cls =>
        gridPattern.test(cls)
      );

      buttonWrapper.className = `${filtered.join(' ')} ${buttonWrapper.className}`;
    }

    buttonWrapper.innerHTML = `
         <div class="content-block--item-action-wrapper--inner">
            <button class="content-block--item-action js-projekt-content-block--add-item">
              <i class="fa fas fa-plus"></i>
              Weiteres Element hinzufügen
            </button>
          </div>
        `

    if (copyStyles) {
      if (lastLi) {
        const lastStyles = getComputedStyle(lastLi)
        const props = ["width", "max-width"];

        props.forEach(prop => {
          const value = lastStyles.getPropertyValue(prop);
          if (value && value !== "auto" && value !== "0px") {
            buttonWrapper.style.setProperty(prop, value);
          }
        });
      }
    }

    return buttonWrapper
  }
}
