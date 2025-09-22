 ProjektStudio.ContentBlockSimpleEdit = {
  initialized: false,

  initialize() {
    this.initEventListeners()
    this.getContentBlockAndSection = ProjektStudio.ContentBlocks.getContentBlockAndSection.bind(ProjektStudio.ContentBlocks)
  },

  initEventListeners() {
    const $document = $(document);
    $document.on("click", ".js-edit-text-projekt-content-block", this.enterSimpleEditMode.bind(this));
    $document.on("click", ".js-projekt-content-block--add-item", this.addNewItemToList.bind(this))
    $document.on("click", ".js-projekt-content-block--delete-last-item", this.deleteLastItemFromList.bind(this))

    $document.on("click", ".js-save-edit-text-projekt-content-block", this.saveContentBlockFromSimpleMode.bind(this));
    $document.on("click", ".js-projekt-content-block--text-edit-cancel", this.cancelSimpleEditMode.bind(this));
    // $document.on("keydown", ".projekt-content-block", this.handleSaveContentBlockEditedTextShortcut.bind(this));
  },

  enterSimpleEditMode(e) {
    const { contentBlockSection, contentBlock } = this.getContentBlockAndSection(e.target)

    contentBlockSection.classList.remove("-highlight-changed")
    contentBlockSection.classList.add("-simple-edit-mode")
    $accordion = $(contentBlock).find('.accordion a');
    $accordion.off("keydown")

    ProjektStudio.ContentBlocks.storePreviousVersionOfContentBlock(contentBlock, contentBlockSection)
    this.toggleContentEditableForContentBlock(contentBlock, true)

    this.addSimpleModeListControls(contentBlock)
  },

  addSimpleModeListControls(contentBlock) {
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
    buttonWrapper.className = "content-block--item-action-wrapper js-content-block--inline-control";
    buttonWrapper.style.listStyle = "none";

    const lastLi = ul.querySelector("li:last-child")


    if (copyStyles) {
      buttonWrapper.className = `${lastLi.classList} ${buttonWrapper.classList}`
    }

    buttonWrapper.innerHTML = `
         <div class="content-block--item-action-wrapper--inner">
            <button class="content-block--item-action js-projekt-content-block--add-item">
              <i class="fa fas fa-plus"></i>
              Weiteres Element hinzufügen
            </button>
            <button class="content-block--item-action js-projekt-content-block--delete-last-item -delete">
              <i class="fa fas fa-trash"></i>
              Letztes Element löschen
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

  addNewItemToList(e) {
    const wrapper = e.currentTarget.closest(".js-content-block--inline-control")
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
      lastLi = ul.querySelector("li:nth-last-child(2):not(.js-content-block--inline-control)")
    }

    const isSlider = ul.classList.contains("orbit-container")

    ProjektStudio.utils.resetFoundationAccordionStateFor(ul)
    const clonedLi = lastLi.cloneNode(true);

    ProjektStudio.utils.removeChildHtmlAttributes(
      clonedLi,
      ["id", "aria-labelledby", "aria-controls", "aria-expanded", "data-slide"]
    )
    const copyId = Date.now();

    let elementToReinitialize = isSlider ? ul.parentElement : ul;
    elementToReinitialize.id = '';

    let elementToReinitializeParent = elementToReinitialize.parentElement;
    elementToReinitialize.dataset.contentBlockCopyId = copyId;
    elementToReinitialize.outerHTML = elementToReinitialize.outerHTML;

    const newElementToReinitialize = elementToReinitializeParent.querySelector(`[data-content-block-copy-id="${copyId}"]`)
    const newUl = isSlider ? elementToReinitializeParent.querySelector('ul') : newElementToReinitialize;

    if (isSlider) {
      const previousSlideNumber = Number.parseInt(lastLi.dataset.slide);
      const newSlideNumber = previousSlideNumber + 1;
      clonedLi.dataset.slide = newSlideNumber;
      this.addBulletToSlider(newUl, newSlideNumber)

      const previousImg = lastLi.querySelector('img')
      const clonedImg = clonedLi.querySelector('img')

      clonedImg.setAttribute("src", previousImg.getAttribute("src").replace(`text=Slide-${previousSlideNumber + 1}`, `text=Slide-${newSlideNumber + 1}`))
      clonedLi.querySelector(".orbit-caption").innerHTML = `Slide ${newSlideNumber + 1}`;

      newUl.append(clonedLi);
    }
    else {
      newUl.insertBefore(clonedLi, newUl.lastElementChild);
    }

    $(newElementToReinitialize).foundation()
  },

  deleteLastItemFromList(e) {
    const deleteConfirmed = confirm("Möchten Sie das letzte Element wirklich aus der Liste löschen?")

    if (!deleteConfirmed) return;

    const wrapper = e.currentTarget.closest(".js-content-block--inline-control")
    let ul = null;

    if (wrapper.dataset.outsideList === "true") {
      ul = wrapper.previousElementSibling.querySelector("ul");
    }
    else {
      ul = e.currentTarget.closest("ul")
    }
    const isSlider = ul.classList.contains("orbit-container")

    if (isSlider) {
      const lastBullet = ul.parentElement.querySelector(".orbit-bullets > button:last-child")
      if (lastBullet.classList.contains("is-active")) {
        lastBullet.previousElementSibling.click()
      }
      lastBullet.remove()
    }

    const lastLi = ul.querySelector("li:nth-last-child(2):not(.js-content-block--inline-control)")
    lastLi.remove()
  },

  addBulletToSlider(ul, newSlideNumber) {
    const bulletsElement = ul.closest(".orbit").querySelector(".orbit-bullets")

    console.log("addBulletToSlider", newSlideNumber)

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

  handleSaveContentBlockEditedTextShortcut(e) {
    if (e.key === "Enter" && (e.metaKey || e.ctrlKey)) {
      this.saveContentBlockFromSimpleMode(e);
    }
  },

  saveContentBlockFromSimpleMode(e) {
    const { contentBlockSection, contentBlock} = this.getContentBlockAndSection(e.target);

    this.removeSimpleEditModeInlineControls(contentBlock);

    if (contentBlockSection.classList.contains("-simple-edit-mode")) {
      contentBlockSection.classList.remove("-simple-edit-mode")
      this.toggleContentEditableForContentBlock(contentBlock, false);

       ProjektStudio.ContentBlocks.updateContentBlock(
        contentBlock,
        contentBlockSection.dataset.contentBlockId,
        contentBlock.innerHTML.trim(),
        true
      )
    }
  },

  cancelSimpleEditMode(e) {
    const { contentBlockSection, contentBlock} = this.getContentBlockAndSection(e.target);

    this.removeSimpleEditModeInlineControls(contentBlock);

    contentBlockSection.classList.remove("-simple-edit-mode")
    contentBlock.innerHTML = contentBlock.dataset.previousContentBlockHtml;
    this.toggleContentEditableForContentBlock(contentBlock, false);

    $(contentBlock).foundation();
  },

  removeSimpleEditModeInlineControls(container) {
    container
      .querySelectorAll(".js-content-block--inline-control")
      .forEach((e) => e.remove())
  },

  toggleContentEditableForContentBlock(contentBlock, contentEditable) {
    const elements = Array.from(contentBlock.querySelectorAll("h2, h3, h4, p, a, .accordion-content, li, ol, .js-text-editable"))

    elements.forEach((element) => {
      if (contentEditable) {
        element.contentEditable = contentEditable;
      }
      else {
        element.removeAttribute("contenteditable")
      }
    })

    if (elements.length === 0) {
      if (contentEditable) {
        contentBlock.contentEditable = contentEditable;
        ProjektStudio.utils.focusContentEditableElement(contentBlock)
      }
      else {
        contentBlock.removeAttribute("contenteditable")
      }
    }
    else {
      const lastElement = elements[elements.length - 1]
      ProjektStudio.utils.focusContentEditableElement(lastElement)
    }
  },
 }
