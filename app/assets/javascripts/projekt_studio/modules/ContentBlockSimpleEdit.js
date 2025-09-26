 ProjektStudio.ContentBlockSimpleEdit = {
  initialized: false,

  initialize() {
    this.initEventListeners()
    this.getContentBlockAndSection = ProjektStudio.ContentBlocks.getContentBlockAndSection.bind(ProjektStudio.ContentBlocks)
  },

  initEventListeners() {
    const $document = $(document);
    $document.on("click", ".js-edit-text-projekt-content-block", this.enterSimpleEditMode.bind(this));
    $document.on("click", ".js-projekt-content-block--add-item", this.addItem.bind(this))
    $document.on("click", ".js-projekt-content-block--delete-last-item", this.deleteLastItemFromList.bind(this))
    $document.on("click", ".js-projekt-content-block--delete-item", this.deleteItem.bind(this))

    $document.on("click", ".js-content-block-image-change-button", this.changeImage.bind(this));

    $document.on("click", ".js-save-edit-text-projekt-content-block", this.saveContentBlockFromSimpleMode.bind(this));
    $document.on("click", ".js-projekt-content-block--text-edit-cancel", this.cancelSimpleEditMode.bind(this));
    $document.on("click", ".js-content-block-disable-link-click", this.disableLinkClick.bind(this));
    // $document.on("keydown", ".projekt-content-block", this.handleSaveContentBlockEditedTextShortcut.bind(this));
  },

  enterSimpleEditMode(e) {
    const { contentBlockSection, contentBlock } = this.getContentBlockAndSection(e.target)

    contentBlockSection.classList.remove("-highlight-changed")
    contentBlockSection.classList.add("-simple-edit-mode")
    $accordion = $(contentBlock).find('.accordion a');
    $accordion.off("keydown")

    ProjektStudio.ContentBlocks.storePreviousVersionOfContentBlock(
      contentBlock, contentBlockSection
    )

    this.addListControls(contentBlock)
    this.addImageControls(contentBlock)

    this.toggleSimpleEditModeFor(contentBlock, true)
  },

  addListControls(contentBlock) {
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
      .querySelectorAll("li:not(.js-content-block--simple-edit-control)")
      .forEach((li) => {
        this.addItemDeleteButton(li)
      })
  },

   addItemDeleteButton(li) {
     const buttonHTML = `
        <button class="content-block--item-delete-button js-projekt-content-block--delete-item js-content-block--simple-edit-control -delete">
        <i class="fa fas fa-trash"></i>
       </button>
     `

     const buttonElement = ProjektStudio.utils.htmlToSingleDomElement(buttonHTML)

     li.style.position = "relative"
     li.appendChild(buttonElement);
   },

  addImageControls(contentBlock) {
    contentBlock
      .querySelectorAll("img")
      .forEach((img) => {
        this.wrapImageWithControls(img)
      })
  },

  wrapImageWithControls(img) {
    const imageWrapper = document.createElement("div")
    imageWrapper.classList.add("content-block-image-wrapper", "js-content-block-image-wrapper")

    const smallButton = img.height < 120;

    imageWrapper.innerHTML = `
      <button
        type="button"
        class="content-block-image-change-button image-change-button js-content-block-image-change-button js-content-block--simple-edit-control ${smallButton ? '-small' : ''}">
          <i class="fa fas fa-pencil-alt"></i>
      </button>
      ${img.outerHTML}
    `

    img.outerHTML = imageWrapper.outerHTML;
  },

  changeImage(e) {
    e.stopPropagation()
    e.stopImmediatePropagation()
    e.preventDefault()

    const wrapper = e.currentTarget.parentElement;
    const img = wrapper.querySelector("img")
    const fileInput = document.querySelector(".js-content-block-image-change-input")
    fileInput.click()

    document.body.addEventListener('change', (e) => {
      this.handleImageAttach(e, img)
    }, { once: true });
  },

   handleImageAttach(e, img) {
     const file = e.target.files && e.target.files[0];
     if (!file) return;

     const reader = new FileReader();
     reader.onload = (evt) => { img.setAttribute('src', evt.target.result); };
     reader.readAsDataURL(file);

     const formData = new FormData();
     formData.append('upload', file);
    formData.append('thumb_width', img.width + 30)
    formData.append('thumb_height', img.width + 30)

     const csrfToken = $('meta[name="csrf-token"]').attr('content');

     $.ajax({
       method: 'POST',
       url: '/ckeditor/pictures',
       headers: {
         'X-CSRF-TOKEN': csrfToken,
       },
       data: formData,
       processData: false,
       contentType: false,
     }).then((response) => {
       this.handleImageUpload(img, response)
     })
   },

   handleImageUpload(img, response) {
     const previousPictureId = img.dataset.pictureId;
     img.src = response.custom_thumb_url
     img.dataset.fullImageUrl = response.url
     img.dataset.pictureId = response.id

     if (previousPictureId && previousPictureId.length > 0) {
       const csrfToken = $('meta[name="csrf-token"]').attr('content');

       $.ajax({
         method: 'DELETE',
         url: `/ckeditor/pictures/${previousPictureId}`,
         headers: {
           'X-CSRF-TOKEN': csrfToken,
         },
       })
     }
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
    buttonWrapper.className = "content-block--item-action-wrapper js-content-block--simple-edit-control";
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

  addItem(e) {
    const wrapper = e.currentTarget.closest(".js-content-block--simple-edit-control")
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
      lastLi = ul.querySelector("li:nth-last-child(2):not(.js-content-block--simple-edit-control)")
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
    elementToReinitialize.dataset.contentBlockCopyId = copyId;

    if (isSlider || isAccordion) {
      elementToReinitialize.outerHTML = elementToReinitialize.outerHTML;
    }

    const newElementToReinitialize = elementToReinitializeParent.querySelector(`[data-content-block-copy-id="${copyId}"]`)
    const newUl = isSlider ? elementToReinitializeParent.querySelector('ul') : newElementToReinitialize;

    if (isSlider) {
      newUl.append(clonedLi);

      this.updateSliderItemAttributes(lastLi, clonedLi)
    }
    else {
      newUl.insertBefore(clonedLi, newUl.lastElementChild);
    }

    $(newElementToReinitialize).foundation()
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

  deleteLastItemFromList(e) {
    const deleteConfirmed = confirm("Möchten Sie das letzte Element wirklich aus der Liste löschen?")

    if (!deleteConfirmed) return;

    const wrapper = e.currentTarget.closest(".js-content-block--simple-edit-control")
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

    const lastLi = ul.querySelector("li:nth-last-child(2):not(.js-content-block--simple-edit-control)")
    lastLi.remove()
  },

  deleteItem(e) {
    const deleteConfirmed = confirm("Möchten Sie das letzte Element wirklich aus der Liste löschen?")

    if (!deleteConfirmed) return;

    const li = e.currentTarget.closest("li")
    const ul = li.closest("ul")

    const isSlider = ul.classList.contains("orbit-container")

    if (isSlider) {
      const lastBullet = ul.parentElement.querySelector(".orbit-bullets > button:last-child")
      if (lastBullet.classList.contains("is-active")) {
        lastBullet.previousElementSibling.click()
      }
      lastBullet.remove()
    }

    li.remove()
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

    if (contentBlockSection.classList.contains("-simple-edit-mode")) {
      contentBlockSection.classList.remove("-simple-edit-mode")
      this.toggleSimpleEditModeFor(contentBlock, false);

      const content =
        contentBlock
          .innerHTML
          .trim()
          .replace(/(<br\s*\/?>\s*){2,}/gi, '<br>');

       ProjektStudio.ContentBlocks.updateContentBlock(
        contentBlock,
        contentBlockSection.dataset.contentBlockId,
        content,
        true
      )
    }
  },

  cancelSimpleEditMode(e) {
    const { contentBlockSection, contentBlock} = this.getContentBlockAndSection(e.target);

    contentBlockSection.classList.remove("-simple-edit-mode")
    contentBlock.innerHTML = contentBlock.dataset.previousContentBlockHtml;

    this.toggleSimpleEditModeFor(contentBlock, false);

    $(contentBlock).foundation();
  },

  removeSimpleEditControls(container) {
    container
      .querySelectorAll(".js-content-block--simple-edit-control")
      .forEach((e) => e.remove())

    container
      .querySelectorAll(".js-content-block-image-wrapper")
      .forEach((imgWrapper) => {
        const img = imgWrapper.querySelector("img")
        imgWrapper.outerHTML = img.outerHTML
      })
  },

   toggleSimpleEditModeFor(contentBlock, state) {
     this.toggleContentEditableFor(contentBlock, state)
     this.toggleLinksClickModeFor(contentBlock, state)

     if (!state) {
       this.removeSimpleEditControls(contentBlock)
     }
   },

   toggleLinksClickModeFor(contentBlock, state) {
     $(contentBlock).find("a").toggleClass("js-content-block-disable-link-click", state)
   },

   toggleContentEditableFor(contentBlock, contentEditable) {
     const elements = Array.from(
       contentBlock.querySelectorAll("h2, h3, h4, p, a, .accordion-content, li, ol, .js-text-editable")
     );

     const hasBlockChildren = (element) => {
       const blockSelectors = [
         "div", "p", "ul", "ol", "li", "section", "article", "header", "footer", "aside", "nav",
         "h1","h2","h3","h4","h5","h6", "blockquote", "pre"
       ];
       return element.querySelector(blockSelectors.join(", ")) !== null;
     };

     elements.forEach((element) => {
       if (!hasBlockChildren(element)) {
         if (contentEditable) {
           element.contentEditable = true;
            ProjektStudio.utils.focusContentEditableElement(contentBlock);
         } else {
           element.removeAttribute("contenteditable");
         }
       } else {
         element.removeAttribute("contenteditable");
       }
     });

     if (elements.length === 0) {
       if (contentEditable) {
         contentBlock.contentEditable = true;
         ProjektStudio.utils.focusContentEditableElement(contentBlock);
       } else {
         contentBlock.removeAttribute("contenteditable");
       }
     }
   },

   disableLinkClick(e) {
     e.preventDefault()
     console.log("disableLinkClick")
   }
}
