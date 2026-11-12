App.Studio.ContentBlocks.SimpleEditMode.ListEdit = {
  listControlClass: "js-content-block--list-control",
  listItemAnchorClass: "studio-content-block-list-item-anchor",
  sortableInstances: new Map(),
  addItemButtonStates: new WeakMap(),
  addItemButtonLists: new WeakMap(),
  addItemButtonGap: 4,

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
        .querySelectorAll(`li:not(.${this.listControlClass})`)
        .forEach((li) => {
          if (this.isInsideFollowerList(li)) return;
          if (li.closest(".js-content-block-element-not-editable")) return;

          this.addItemControlls(li)
        })

      this.showAddItemButtons(contentBlock)
      this.initSortableForContentBlock(contentBlock)
    }
    else {
      contentBlock
        .querySelectorAll(`.${this.listControlClass}`)
        .forEach((e) => e.remove())

      this.removeListItemAnchors(contentBlock)
      this.hideAddItemButtons(contentBlock)
      this.cleanupSortableForContentBlock(contentBlock)
    }
  },

  getEditableLists(contentBlock) {
    return Array.from(contentBlock.querySelectorAll("ul, ol")).filter((list) => {
      return !this.isFollowerList(list) &&
        !list.closest(".js-content-block-element-not-editable")
    })
  },

  getAddItemAnchor(list) {
    const foundationSlider = list.closest(".orbit")

    if (foundationSlider) return foundationSlider

    const outsideOfSelector = list.dataset.listEditAddOutsideOf

    if (list.hasAttribute("data-list-edit-add-outside") && outsideOfSelector) {
      return list.closest(outsideOfSelector) || list
    }

    return list
  },

  showAddItemButtons(contentBlock) {
    const layer = this.getAddItemButtonLayer(contentBlock)

    if (!layer) return

    this.hideAddItemButtons(contentBlock)

    const entries = this.sortByListNestingDepth(this.getEditableLists(contentBlock).map((list) => {
      const button = this.buildAddItemButton()

      layer.appendChild(button)
      this.addItemButtonLists.set(button, list)

      return { button, list, anchor: this.getAddItemAnchor(list) }
    }))

    const state = { layer, entries, frameRequest: null }
    const scheduleUpdate = () => this.scheduleAddItemButtonsUpdate(contentBlock)

    state.resizeObserver = new ResizeObserver(scheduleUpdate)
    state.resizeObserver.observe(contentBlock)
    entries.forEach(({ anchor }) => state.resizeObserver.observe(anchor))

    state.mutationObserver = new MutationObserver(scheduleUpdate)
    state.mutationObserver.observe(contentBlock, { childList: true, subtree: true })

    this.addItemButtonStates.set(contentBlock, state)
    this.positionAddItemButtons(state)
  },

  hideAddItemButtons(contentBlock) {
    const state = this.addItemButtonStates.get(contentBlock)

    if (!state) return

    state.resizeObserver.disconnect()
    state.mutationObserver.disconnect()
    cancelAnimationFrame(state.frameRequest)
    state.entries.forEach(({ button }) => button.remove())

    this.addItemButtonStates.delete(contentBlock)
  },

  getAddItemButtonLayer(contentBlock) {
    return contentBlock.closest(".custom-content-block-wrapper--inner")
  },

  scheduleAddItemButtonsUpdate(contentBlock) {
    const state = this.addItemButtonStates.get(contentBlock)

    if (!state || state.frameRequest) return

    state.frameRequest = requestAnimationFrame(() => {
      state.frameRequest = null
      this.updateAddItemButtons(contentBlock, state)
    })
  },

  updateAddItemButtons(contentBlock, state) {
    if (this.addItemButtonStates.get(contentBlock) !== state) return

    if (!contentBlock.isConnected) {
      this.hideAddItemButtons(contentBlock)
      return
    }

    const isStale = state.entries.some(({ list }) => !list.isConnected)

    if (isStale) {
      this.showAddItemButtons(contentBlock)
      return
    }

    this.positionAddItemButtons(state)
  },

  positionAddItemButtons({ layer, entries }) {
    const layerRect = layer.getBoundingClientRect()
    const measuredEntries = entries.map((entry) => {
      const anchorRect = entry.anchor.getBoundingClientRect()

      return { ...entry, anchorRect, isAnchorRendered: anchorRect.width > 0 || anchorRect.height > 0 }
    })

    measuredEntries.forEach(({ button, isAnchorRendered }) => {
      button.classList.toggle("-hidden", !isAnchorRendered)
    })

    const renderedEntries = measuredEntries
      .filter(({ isAnchorRendered }) => isAnchorRendered)
      .map((entry) => ({ ...entry, width: entry.button.offsetWidth, height: entry.button.offsetHeight }))
    const placedBoxes = []

    renderedEntries.forEach((entry) => {
      const halfButtonWidth = entry.width / 2
      const anchorCenter = entry.anchorRect.left - layerRect.left + entry.anchorRect.width / 2
      const center = App.Studio.utils.clampCenterInside(anchorCenter, halfButtonWidth, layerRect.width)
      const edge = entry.anchorRect.bottom - layerRect.top
      const box = this.findFreeAddItemButtonBox(placedBoxes, {
        left: center - halfButtonWidth,
        right: center + halfButtonWidth,
        top: edge - entry.height / 2,
        bottom: edge + entry.height / 2
      })

      placedBoxes.push(box)
      entry.center = center
      entry.middle = (box.top + box.bottom) / 2
    })

    renderedEntries.forEach(({ button, center, middle }) => {
      button.style.left = `${center}px`
      button.style.top = `${middle}px`
    })
  },

  findFreeAddItemButtonBox(placedBoxes, box) {
    const overlaps = (placedBox) => App.Studio.utils.boxesOverlap(placedBox, box)
    let coveredBox = placedBoxes.find(overlaps)

    while (coveredBox) {
      const shift = coveredBox.bottom + this.addItemButtonGap - box.top

      box = { ...box, top: box.top + shift, bottom: box.bottom + shift }
      coveredBox = placedBoxes.find(overlaps)
    }

    return box
  },

  sortByListNestingDepth(entries) {
    const depth = ({ list }) => {
      let count = 0
      let ancestor = list.parentElement.closest("ul, ol")

      while (ancestor) {
        count += 1
        ancestor = ancestor.parentElement.closest("ul, ol")
      }

      return count
    }

    return entries
      .map((entry) => ({ entry, depth: depth(entry) }))
      .sort((a, b) => b.depth - a.depth)
      .map(({ entry }) => entry)
  },

  buildAddItemButton() {
    return App.Studio.utils.htmlToSingleDomElement(`
      <button
        type="button"
        class="studio-content-block-list-add-button js-content-block--add-item js-studio-hide-on-preview"
      >
        <i class="fas fa-plus" aria-hidden="true"></i>
        Weiteres Element hinzufügen
      </button>
    `)
  },

  isFollowerList(ul) {
    return ul.hasAttribute("data-list-edit-follower")
  },

  isInsideFollowerList(li) {
    const parentList = li.closest("ul, ol");
    return parentList && this.isFollowerList(parentList);
  },

  removeListItemAnchors(element) {
    element
      .querySelectorAll(`.${this.listItemAnchorClass}`)
      .forEach((li) => App.Studio.utils.removeClasses(li, [this.listItemAnchorClass]))
  },

  addItemControlls(li) {
    const elementStyle = getComputedStyle(li);
    if (elementStyle.position === "static") {
      li.classList.add(this.listItemAnchorClass)
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
    const addButton = e.currentTarget
    const isAddButtonFocused = document.activeElement === addButton
    const ul = this.addItemButtonLists.get(addButton)
    const contentBlock = ul.closest(".js-content-block")
    const realListItems = this.getRealListItems(ul)
    const lastLi = realListItems[realListItems.length - 1]

    if (!lastLi) return

    const isSlider = ul.classList.contains("orbit-container")
    const isAccordion = ul.classList.contains("accordion")

    App.Studio.utils.resetFoundationAccordionStateFor(ul)
    const clonedLi = lastLi.cloneNode(true);

    clonedLi
      .querySelectorAll(`:scope > .${this.listControlClass}`)
      .forEach((control) => control.remove())

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

    const newUl = isSlider ? newElementToReinitialize.querySelector(".orbit-container") : newElementToReinitialize;

    newUl.appendChild(clonedLi);

    if (isSlider) {
      this.updateSliderItemAttributes(lastLi, clonedLi)
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

    this.showAddItemButtons(contentBlock)

    if (isAddButtonFocused) {
      this.focusAddItemButton(contentBlock, newUl)
    }
  },

  focusAddItemButton(contentBlock, list) {
    const { entries } = this.addItemButtonStates.get(contentBlock)
    const { button } = entries.find((entry) => entry.list === list)

    button.focus({ preventScroll: true })
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
