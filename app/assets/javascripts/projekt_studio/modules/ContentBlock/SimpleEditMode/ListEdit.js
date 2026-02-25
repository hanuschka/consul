ProjektStudio.ContentBlock.SimpleEditMode.ListEdit = {
  listControlClass: "js-content-block--list-control",
  sortableInstances: new Map(),

  initialize() {
    this.initEventListeners()
  },

  initEventListeners() {
    const $document = $(document);
    $document.on("click", ".js-projekt-content-block--add-item", this.addItem.bind(this))
    $document.on("click", ".js-projekt-content-block--delete-item", this.deleteItem.bind(this))
  },

  toggleListControls(contentBlock, enabled) {
    if (enabled) {
      contentBlock
        .querySelectorAll("ul, ol")
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
          this.addItemControlls(li)
        })

      this.initSortableForContentBlock(contentBlock)
    }
    else {
      contentBlock
        .querySelectorAll(`.${this.listControlClass}`)
        .forEach((e) => e.remove())

      this.cleanupSortableForContentBlock(contentBlock)
    }
  },

  addItemControlls(li) {
    const elementStyle = getComputedStyle(li);
    if (elementStyle.position === "static") {
      li.style.position = "relative"
    }

    let baseClass = "content-block--item-button"

    if (li.clientHeight < 70) {
      baseClass += " -small"
    }

    // console.log("ProjektStudio.ContentBlock.DomHelpers.isSliderItem(li)", ProjektStudio.ContentBlock.DomHelpers.isSliderItem(li))
    if (!ProjektStudio.ContentBlock.DomHelpers.isSliderItem(li)) {
      const dragHandleHTML = `
        <button
          class="content-block--item-drag-handle ${baseClass} ${this.listControlClass} js-list-item-dnd-handle js-content-block-element-not-editable js-projekt-studio-hide-on-preview -drag"
          title="Element verschieben"
          contenteditable="false"
        >
        <i class="fas fa-up-down-left-right"></i>
       </button>
     `
      const dragHandleElement = ProjektStudio.utils.htmlToSingleDomElement(dragHandleHTML)
      li.appendChild(dragHandleElement);
    }

    const deleteButtonHtml = `
        <button
          class="content-block--item-delete-button ${baseClass} ${this.listControlClass} js-projekt-content-block--delete-item js-content-block-element-not-editable js-projekt-studio-hide-on-preview -delete"
          contenteditable="false"
        >
        <i class="fa fas fa-trash"></i>
       </button>
     `
    const deleteButton = ProjektStudio.utils.htmlToSingleDomElement(deleteButtonHtml)
    li.appendChild(deleteButton);
  },


  addItem(e) {
    const wrapper = e.currentTarget.closest(`.${this.listControlClass}`)
    let ul = null;
    let ulParent;
    let lastLi;

    if (wrapper.dataset.outsideList === "true") {
      ulParent = wrapper.previousElementSibling;
      ul = ulParent.querySelector("ul, ol");
      lastLi = ul.querySelector("li:last-child")
    }
    else {
      ul = e.currentTarget.closest("ul, ol")
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

    this.addItemControlls(clonedLi)
    this.cleanupSortableForContentBlock(newUl.parentElement)
    this.initSortableForContentBlock(newUl.parentElement)
  },

  updateSliderItemAttributes(lastLi, clonedLi) {
    const previousSlideNumber = Number.parseInt(lastLi.dataset.slide);
    const newSlideNumber = previousSlideNumber + 1;
    clonedLi.dataset.slide = newSlideNumber;

    this.addBulletToSlider(clonedLi.closest("ul, ol"), newSlideNumber)

    const previousImg = lastLi.querySelector('img')
    const clonedImg = clonedLi.querySelector('img')

    clonedImg.setAttribute("src", previousImg.getAttribute("src").replace(`text=Slide-${previousSlideNumber + 1}`, `text=Slide-${newSlideNumber + 1}`))
    clonedLi.querySelector(".orbit-caption").innerHTML = `Slide ${newSlideNumber + 1}`;
  },

  deleteItem(e) {
    const deleteConfirmed = confirm("Möchten Sie das letzte Element wirklich aus der Liste löschen?")

    if (!deleteConfirmed) return;

    console.log("e.currentTarget", e.currentTarget)
    const li = e.currentTarget.closest("li")
    if (!li) return;

    const ul = li.closest("ul, ol")
    if (!ul) return;

    const isSlider = ul.classList.contains("orbit-container")

    if (isSlider) {
      const lastBullet = ul.closest(".orbit").querySelector(".orbit-bullets > button:last-child")
      if (lastBullet && lastBullet.classList.contains("is-active")) {
        lastBullet.previousElementSibling.click()
      }
      if (lastBullet) {
        lastBullet.remove()
      }
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
    buttonWrapper.className = `content-block--item-action-wrapper ${this.listControlClass} js-content-block-element-not-editable`;
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
      <div class="content-block--item-action-wrapper--inner js-projekt-studio-hide-on-preview">
          <button class="content-block--item-action js-projekt-content-block--add-item js-content-block-element-not-editable">
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
  },

  initSortableForContentBlock(contentBlock) {
    setTimeout(() => {
      contentBlock
        .querySelectorAll("ul, ol")
        .forEach((ul) => {
          if (this.sortableInstances.has(ul)) return;
          if (ul.classList.contains("orbit-container")) return;

          const sortableInstance = new Sortable(ul, {
            handle: ".js-list-item-dnd-handle",
            animation: 150,
            ghostClass: 'list-item-dnd-placeholder',
            dragClass: "list-item-dnd-move",
            scrollSensitivity: 2,
            scrollSpeed: 3,
            draggable: `li:not(.${this.listControlClass})`
          })

          this.sortableInstances.set(ul, sortableInstance)
        })
    }, 50)
  },

  cleanupSortableForContentBlock(contentBlock) {
    const ulElements = contentBlock.querySelectorAll("ul, ol")

    ulElements.forEach((ul) => {
      const sortableInstance = this.sortableInstances.get(ul)
      if (sortableInstance) {
        sortableInstance.destroy()
        this.sortableInstances.delete(ul)
      }
    })
  }
}
