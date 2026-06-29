App.Studio.ContentBlocks.SimpleEditMode.ListEdit = {
  listControlClass: "js-content-block--list-control",
  sortableInstances: new Map(),

  initialize() {
    this.initEventListeners()
  },

  initEventListeners() {
    const $document = $(document);
    $document.on("click", ".js-content-block--add-item", this.addItem.bind(this))
    $document.on("click", ".js-content-block--delete-item", this.deleteItem.bind(this))
  },

  toggleListControls(contentBlock, enabled) {
    if (enabled) {
      contentBlock
        .querySelectorAll("ul, ol")
        .forEach((ul) => {
          if (this.isFollowerList(ul)) return;
          if (ul.closest(".js-content-block-element-not-editable")) return;

          const foundationSlider = ul.closest(".orbit")

          if (foundationSlider) {
            this.addNewSliderItemButton(ul)
          } else if (ul.hasAttribute("data-list-edit-add-outside")) {
            this.addNewOutsideItemButton(ul)
          } else {
            this.addNewItemButton(ul)
          }
        })

      contentBlock
        .querySelectorAll(`li:not(.${this.listControlClass})`)
        .forEach((li) => {
          if (this.isInsideFollowerList(li)) return;
          if (li.closest(".js-content-block-element-not-editable")) return;

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

  isFollowerList(ul) {
    return ul.hasAttribute("data-list-edit-follower")
  },

  isInsideFollowerList(li) {
    const parentList = li.closest("ul, ol");
    return parentList && this.isFollowerList(parentList);
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

    // console.log("App.Studio.ContentBlocks.DomHelpers.isSliderItem(li)", App.Studio.ContentBlocks.DomHelpers.isSliderItem(li))
    if (!App.Studio.ContentBlocks.DomHelpers.isSliderItem(li)) {
      const dragHandleHTML = `
        <button
          class="content-block--item-drag-handle ${baseClass} ${this.listControlClass} js-list-item-dnd-handle js-content-block-element-not-editable js-studio-hide-on-preview -drag"
          title="Element verschieben"
          contenteditable="false"
        >
        <i class="fas fa-up-down-left-right"></i>
       </button>
     `
      const dragHandleElement = App.Studio.utils.htmlToSingleDomElement(dragHandleHTML)
      li.appendChild(dragHandleElement);
    }

    const deleteButtonHtml = `
        <button
          class="content-block--item-delete-button ${baseClass} ${this.listControlClass} js-content-block--delete-item js-content-block-element-not-editable js-studio-hide-on-preview -delete"
          contenteditable="false"
        >
        <i class="fa fas fa-trash"></i>
       </button>
     `
    const deleteButton = App.Studio.utils.htmlToSingleDomElement(deleteButtonHtml)
    li.appendChild(deleteButton);
  },


  addItem(e) {
    const wrapper = e.currentTarget.closest(`.${this.listControlClass}`)
    const isOutsideList = wrapper.dataset.outsideList === "true";
    let ul = null;
    let lastLi;

    if (isOutsideList) {
      const prev = wrapper.previousElementSibling;
      ul = prev.matches("ul, ol") ? prev : prev.querySelector("ul, ol");
      lastLi = ul.querySelector(`li:last-child:not(.${this.listControlClass})`)
    }
    else {
      ul = e.currentTarget.closest("ul, ol")
      lastLi = ul.querySelector(`li:nth-last-child(2):not(.${this.listControlClass})`)
    }

    const isSlider = ul.classList.contains("orbit-container")
    const isAccordion = ul.classList.contains("accordion")

    App.Studio.utils.resetFoundationAccordionStateFor(ul)
    const clonedLi = lastLi.cloneNode(true);

    App.Studio.utils.removeChildHtmlAttributes(
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
    else if (isOutsideList) {
      newUl.appendChild(clonedLi);
    }
    else {
      newUl.insertBefore(clonedLi, newUl.lastElementChild);
    }

    App.Studio.ContentBlocks.DomHelpers.reinitFoundationWidgets(newElementToReinitialize)

    if (isAccordion) {
      const $accordionLinks = $(newElementToReinitialize).find('.accordion-title');
      $accordionLinks.off("keydown")
    }

    this.addItemControlls(clonedLi)
    this.cleanupSortableForContentBlock(newUl.parentElement)
    this.initSortableForContentBlock(newUl.parentElement)

    this.mirrorAddToFollower(newUl, clonedLi)
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

    const deletedIndex = this.getRealListItems(ul).indexOf(li);

    li.remove()

    this.mirrorDeleteToFollower(ul, deletedIndex)
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

    const newBullet = App.Studio.utils.htmlToSingleDomElement(newBulletHTML)
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

  addNewOutsideItemButton(ul) {
    const buttonWrapper = this.buildItemManagmentControls(ul, { elementType: "div", copyStyles: false })
    buttonWrapper.dataset.outsideList = true

    const outsideOfSelector = ul.dataset.listEditAddOutsideOf;
    const anchor = outsideOfSelector ? ul.closest(outsideOfSelector) : ul;

    (anchor || ul).after(buttonWrapper);
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
      <div class="content-block--item-action-wrapper--inner js-studio-hide-on-preview">
          <button class="content-block--item-action js-content-block--add-item js-content-block-element-not-editable">
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
          if (this.isFollowerList(ul)) return;

          const sortableInstance = new Sortable(ul, {
            handle: ".js-list-item-dnd-handle",
            animation: 150,
            ghostClass: 'list-item-dnd-placeholder',
            dragClass: "list-item-dnd-move",
            scrollSensitivity: 2,
            scrollSpeed: 3,
            draggable: `li:not(.${this.listControlClass})`,
            onEnd: (evt) => this.handleSortableEnd(ul, evt)
          })

          this.sortableInstances.set(ul, sortableInstance)
        })
    }, 50)
  },

  handleSortableEnd(primaryUl, evt) {
    if (evt.oldIndex === evt.newIndex) return;

    this.mirrorReorderToFollower(primaryUl, evt.oldIndex, evt.newIndex)
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
  },

  getRealListItems(ul) {
    return Array.from(ul.querySelectorAll(`:scope > li:not(.${this.listControlClass})`))
  },

  getPairedFollower(primaryUl) {
    const selector = primaryUl.getAttribute("data-paired-list");
    if (!selector) return null;

    const contentBlock = primaryUl.closest(".js-content-block");
    if (!contentBlock) return null;

    return contentBlock.querySelector(selector);
  },

  mirrorAddToFollower(primaryUl, primaryClonedLi) {
    const followerUl = this.getPairedFollower(primaryUl);
    if (!followerUl) return;

    const followerItems = this.getRealListItems(followerUl);
    const followerLastLi = followerItems[followerItems.length - 1];
    if (!followerLastLi) return;

    const followerClone = followerLastLi.cloneNode(true);

    App.Studio.utils.removeChildHtmlAttributes(
      followerClone,
      ["id", "aria-labelledby", "aria-controls", "aria-expanded", "data-slide"]
    )

    followerUl.appendChild(followerClone);

    const index = this.getRealListItems(primaryUl).indexOf(primaryClonedLi);

    this.dispatchPairedItemCloned(primaryClonedLi, followerClone, index)
  },

  mirrorDeleteToFollower(primaryUl, deletedIndex) {
    const followerUl = this.getPairedFollower(primaryUl);
    if (!followerUl) return;
    if (deletedIndex < 0) return;

    const followerItems = this.getRealListItems(followerUl);
    const followerLi = followerItems[deletedIndex];

    if (followerLi) followerLi.remove();
  },

  mirrorReorderToFollower(primaryUl, oldIndex, newIndex) {
    const followerUl = this.getPairedFollower(primaryUl);
    if (!followerUl) return;

    const followerItems = this.getRealListItems(followerUl);
    const moved = followerItems[oldIndex];
    if (!moved) return;

    const remaining = followerItems.filter((li) => li !== moved);
    const reference = remaining[newIndex];

    if (reference) {
      followerUl.insertBefore(moved, reference);
    } else {
      followerUl.appendChild(moved);
    }
  },

  dispatchPairedItemCloned(primaryLi, followerLi, index) {
    const event = new CustomEvent("paired-list:item-cloned", {
      bubbles: true,
      detail: { primaryLi, followerLi, index }
    });

    followerLi.dispatchEvent(event);
  }
}
