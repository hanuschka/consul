// import { Idiomorph } from "idiomorph/dist/idiomorph.esm.js"
// import { Sortable } from 'sortablejs';

// import ace from "ace-builds/src-min/ace"
// import 'ace-builds/src-noconflict/mode-html'
// import 'ace-builds/src-noconflict/worker-html';

// import { resetFoundationAccordionStateFor } from "consul/utils/foundationUtils";
// import { addStudioControlsToContentBlock, addNewContentBlockButtonToContentBlockList, newContentBlockButtonSectionHtml } from "consul/projekt_studio_consul/templates/renderContentBlockControlsFunctions";
// import { htmlToDomElement, focusContentEditableElement } from "utils/htmlUtils";
// import { getCurrentProjektId } from "lib/projekts";
// import { ProjektStudio.utils.sendMessageToDtParentFrame, parseIframeEventData } from "consul/utils/iframeUtils";

 ProjektStudio.modules.ContentBlocks = {
  initialized: false,
  draftContentBlockIndex: 0,
  aceInstances: {},

  initialize() {
    this.initEventListeners()
    this.initUI()
  },

  initEventListeners() {
    $(document).on("click", ".js-show-content-block-templates", this.showContentBlockTemplates.bind(this));
    $(document).on("click", ".js-add-new-content-block", this.addNewContentBlock.bind(this));

    $(document).on("click", ".js-projekt-content-block--regenerate", this.handleRegenerateContentBlock.bind(this));
    $(document).on("click", ".js-projekt-content-block--ai-edit", this.enterAiEditMode.bind(this));
    $(document).on("click", ".js-delete-projekt-content-block", this.deleteContrentBlock.bind(this));

    $(document).on("click", ".js-edit-text-projekt-content-block", this.enterTextEditMode.bind(this));
    $(document).on("click", ".js-html-edit-content-block", this.enterHtmlEditMode.bind(this));
    $(document).on("click", ".js-code-edit-content-block", this.enterCodeEditMode.bind(this));

    $(document).on("click", ".js-projekt-content-block--text-edit-cancel", this.cancelTextEditMode.bind(this));
    $(document).on("click", ".js-projekt-content-block--html-edit-cancel", this.cancelHtmlEditMode.bind(this));
    $(document).on("click", ".js-projekt-content-block--ai-edit-cancel", this.cancelAiEditMode.bind(this));

    $(document).on("click", ".js-save-edit-text-projekt-content-block", this.saveContentBlockEditedText.bind(this));
    $(document).on("click", ".js-save-edit-html-projekt-content-block", this.saveContentBlockEditedHtml.bind(this));

    $(document).on("click", ".js-content-block-reset-to-prev-version", this.resetToPreviousVersion.bind(this));

    $(document).on("keydown", ".projekt-content-block", this.handleSaveContentBlockEditedTextShortcut.bind(this));

    $(document).on("click", ".js-frame-open-admin-page", this.handleOpenAdminPage.bind(this));

    window.addEventListener('message', this.handleGlobalMessage.bind(this));
  },

  handleGlobalMessage(event) {
    if (event.data) {
      const data = ProjektStudio.utils.parseIframeEventData(event.data);
      const params = data.params

      switch(data.event_type) {
        case "Consul.ProjektStudioConsul.setContentBlockTemplates":
          this.setContentBlockTemplates(params);
          break;
        case "updateContentBlockOnUi":
          this.updateContentBlockOnUi(params);
          break;
        case "setDataForFreshContentBlockOnUI":
          this.setDataForFreshContentBlockOnUI(params);
          break;
        case "updateHTML":
          this.morphElementHTML(params.selector, params.html)
          break;
        case "toggleLockContentBlockEdit":
          this.toggleLockContentBlockEdit(params,contentBlockId, params.locked)
          break;
        case "Consul.signinWithToken":
          this.signinWithToken(params)
          break;
      }
    }
  },

  initUI() {
    const projektPageContent =  document.querySelector(".custom-page-content");

    if (!projektPageContent) return

    const html = projektPageContent.outerHTML;
    let parser = new DOMParser();
    let doc = parser.parseFromString(html, 'text/html');

    const contentBlocks = Array.from(doc.querySelectorAll('.projekt-content-block'));
    let wrappedContentBlocksHtml;

    const projektId = ProjektStudio.getCurrentProjektId()

    if (contentBlocks.length > 0) {
      wrappedContentBlocksHtml = Array.from(contentBlocks).map((contentBlock) => {
        return ProjektStudio.templateFunctions.addStudioControlsToContentBlock(
          contentBlock.innerHTML,
          {
            projektId,
            contentBlockId: contentBlock.dataset.id
          }
        );
      }).join("")
    }
    else {
      wrappedContentBlocksHtml = newContentBlockButtonSectionHtml(projektId);
    }

    const newHtml = ProjektStudio.templateFunctions.addNewContentBlockButtonToContentBlockList(wrappedContentBlocksHtml, projektId)

    setTimeout(() => {
      this.morphElementHTML(".custom-page-content-inner", newHtml);
      App.ImageGallery.initialize();
    }, 0)
  },

  setContentBlockTemplates(params) {
    const initialTemplatesContainer = document.querySelector(".js-content-block-templates-load-container")

    initialTemplatesContainer.innerHTML = params.templates
  },

  enterAiEditMode(e) {
    this.turnOnAiEditContentBlockMode(this.findParentContentBlockSection(e.target))
  },

  handleRegenerateContentBlock(e) {
    this.regenerateContentBlock(this.findParentContentBlockSection(e.target), e.currentTarget.dataset.regenerateType)
  },

  regenerateContentBlock(contentBlockSection, regenerateType) {
    this.cancelAllContentBlockRegenerateLoadStates();

    contentBlockSection.classList.add("-loading");

    // this.toggleLockContentBlockEdit(contentBlockSection.dataset.contentBlockId, true)

    const contentBlock = contentBlockSection.querySelector(".projekt-content-block");
    const contentBlockHTML = contentBlock.innerHTML;

    this.storePreviousVersionOfContentBlock(contentBlock, contentBlockSection)

    ProjektStudio.utils.sendMessageToDtParentFrame("regenerateContentBlock", {
      regenerate_type: regenerateType,
      content_block_id: contentBlockSection.dataset.contentBlockId,
      html: contentBlockHTML
    })
  },

  turnOnAiEditContentBlockMode(contentBlockSection) {
    this.cancelAllContentBlockRegenerateLoadStates();

    contentBlockSection.classList.add("-ai-edit-mode");
    const contentBlock = contentBlockSection.querySelector(".projekt-content-block");
    // TODO
    // this.toggleLockAiFunctions(true);
    // this.toggleLockContentBlockEdit(contentBlockSection.dataset.contentBlockId, true)

    ProjektStudio.utils.sendMessageToDtParentFrame("aiEditContentBlock", {
      content_block_id: contentBlockSection.dataset.contentBlockId,
      html: contentBlock.innerHTML
    })
  },

  toggleLockContentBlockEdit(contentBlockId, locked) {
    const contentBlockSection = document.querySelector(`.js-projekt-content-block-edit-section[data-content-block-id='${contentBlockId}']`)
    const controlls = contentBlockSection.querySelector(".js-projekt-content-block-edit-standard-controlls")

    const title = locked ? "Edit is locked while ai process is running" : ""
    controlls.title = title

    const buttons = controlls.querySelectorAll("button")

    buttons.forEach((button) => {
      if (locked) {
        button.dataset.originalTitle = button.title
      }

      const buttonTitle = locked ? "Edit is locked while ai process is running" : button.dataset.originalTitle

      button.disabled = locked
      button.title = buttonTitle
    })
  },

  morphElementHTML(selector, html, afterUpdate = null) {
    const element = document.querySelector(selector);
    // e.innerHTML = data.html;
    //
    setTimeout(() => {
      Idiomorph.morph(element, html, {
        morphStyle:'innerHTML',
        callbacks: {
        }
      })

      setTimeout(() => {
        this.initSortable();
        $(element).foundation();
      }, 100)
    }, 0)
  },

  initSortable() {
    setTimeout(() => {
      const element = document.querySelector(".content-blocks-container");

      new Sortable(
        element, {
          handle: ".js-dnd-handle",
          animation: 150,
          ghostClass: 'content-block-dnd-placeholder',
          dragClass: "content-block-dnd-move",
          scrollSensitivity: 2,
          scrollSpeed: 3,
          onUpdate: (e) => { this.handleContentBlockMovedOnUi(e) },
        });
    }, 3000)
  },

  handleContentBlockMovedOnUi(e) {
    const contentBlockId = e.item.dataset.contentBlockId

    ProjektStudio.utils.sendMessageToDtParentFrame("moveContentBlock", {
      content_block_id: contentBlockId,
      new_position: e.newIndex + 1
    })
  },

  setDataForFreshContentBlockOnUI(params) {
    const newContentBlock = document.querySelector(
      `.js-projekt-content-block-edit-section[data-draft-index='${params.draft_content_block_index}']`
    )

    newContentBlock.dataset.contentBlockId = params.content_block_id;
    newContentBlock.dataset.draft = false;
    newContentBlock.classList.remove('-draft')

    if (params.enter_ai_mode === "true") {
      this.turnOnAiEditContentBlockMode(newContentBlock);
    }
  },

  getContentBlockSectionForId(contentBlockId) {
    return document.querySelector(`.js-projekt-content-block-edit-section[data-content-block-id="${contentBlockId}"]`);
  },

  updateContentBlockOnUi(params) {
    // const contentBlock = document.querySelector(
    //   '.js-projekt-content-block-edit-section[data-content-block-id="' + params.content_block_id + '"] .projekt-content-block'
    // )
    const contentBlockSection = this.getContentBlockSectionForId(params.content_block_id)
    const contentBlock = contentBlockSection.querySelector('.projekt-content-block')

    this.storePreviousVersionOfContentBlock(contentBlock, contentBlockSection)

    contentBlock.innerHTML = params.html

    $(contentBlock).foundation();
    App.ImageGallery.initialize();

    contentBlockSection
      .classList
      .remove('-loading')

    contentBlockSection
      .classList
      .remove("-ai-edit-mode")
  },

  findParentContentBlockSection(element) {
    return element.closest('.js-projekt-content-block-edit-section');
  },

  deleteContrentBlock(e) {
    this.closeAllOpenedContentBlockTemplatesDialogs();

    const deleteConfirmed = confirm("Soll dieser Inhaltsblock wirklich gelöscht werden?")

    if (!deleteConfirmed) return

    const contentBlockSection = this.findParentContentBlockSection(e.target);
    const contentBlockId = contentBlockSection.dataset.contentBlockId;
    const nextContentBlockSection = contentBlockSection.nextElementSibling;
    const prevContentBlockSection = contentBlockSection.previousElementSibling;
    const scrollTo = nextContentBlockSection || prevContentBlockSection;

    contentBlockSection.remove()

    if ($('.js-projekt-content-block-edit-section').length === 0) {
      const projektId = getCurrentProjektId()
      const wrappedContentBlocksHtml = newContentBlockButtonSectionHtml(projektId);
      const newHtml = ProjektStudio.templateFunctions.addNewContentBlockButtonToContentBlockList(wrappedContentBlocksHtml, projektId)

      this.morphElementHTML(".custom-page-content-inner", newHtml);
    }

    if (scrollTo) {
      scrollTo.scrollIntoView({block: "center"});
    }

    ProjektStudio.utils.sendMessageToDtParentFrame("deleteContentBlock", {
      content_block_id: contentBlockId
    })
  },

  closeAllOpenedContentBlockTemplatesDialogs: function() {
    $('.js-show-content-block-templates-section.-opened').removeClass('-opened');
  },

  cancelAllContentBlockRegenerateLoadStates: function() {
    $('.js-projekt-content-block-edit-section.-loading').removeClass('-loading');
    $('.js-projekt-content-block-edit-section.-ai-edit-mode').removeClass('-ai-edit-mode');
  },

  showContentBlockTemplates(e) {
    const parentElement = e.currentTarget.parentElement;
    const templateContainer = parentElement.querySelector(".js-show-content-block-templates-content")

    parentElement.classList.toggle("-opened")

    // if (!parentElement.classList.contains("-templates-added")) {
    if (parentElement.classList.contains("-opened")) {
      const template = document.querySelector('.js-projekt-content-block-templates-selector')
      // const templateContent = template.content.cloneNode(true)
      const templateContent = template.firstElementChild.cloneNode(true)
      const contentBlockSection = this.findParentContentBlockSection(templateContainer);
      const tabsId = "projekt-content-block-templates-tabs-" + contentBlockSection.dataset.contentBlockId;
      const tabs = templateContent.querySelector(".tabs");
      const tabsContent = templateContent.querySelector(".tabs-content");

      tabs.id = tabsId;
      tabsContent.dataset.tabsContent = tabsId;

      const eachTab = tabs.querySelectorAll(".tabs-title a");
      const eachTabPanel = tabsContent.querySelectorAll(".tabs-panel");

      // console.log({eachTab})
      // console.log({eachTabPanel})
      // console.log({tabsId})

      // Make tab ID uniq for foundation tabs to work correctly
      eachTab.forEach(function(tab, index) {
        tab.href = "#" + tabsId + "-" + index;
      });
      eachTabPanel.forEach(function(tabPanel, index) {
        tabPanel.id = tabsId + "-" + index;
      });

      templateContainer.replaceChildren(templateContent);
      // parentElement.classList.add("-templates-added")

      const $tabs = $(templateContainer.querySelector('.tabs'))
      $tabs.foundation()

      $tabs.on('change.zf.tabs', () => {
        'tab changed'
      });
    } else {
      templateContainer.replaceChildren('')
    }
  },

  addNewContentBlock(e) {
    this.closeAllOpenedContentBlockTemplatesDialogs();

    const contentTemplate = e.currentTarget.querySelector(".js-content-block-template-content");
    const previousContentBlockSection = this.findParentContentBlockSection(e.currentTarget);
    const previousContentBlockId = previousContentBlockSection.dataset.contentBlockId;
    const draftContentBlockIndex = this.draftContentBlockIndex;

    const newContentBlockHTML = ProjektStudio.templateFunctions.addStudioControlsToContentBlock(
      contentTemplate.innerHTML, {
        draftContentBlockIndex: this.draftContentBlockIndex
      }
    )
    this.draftContentBlockIndex++;

    const newContentBlock = ProjektStudio.utils.htmlToDomElement(newContentBlockHTML).firstChild;
    newContentBlock.dataset.draft = true;
    newContentBlock.classList.add('-draft')
    newContentBlock.classList.add('-highlight-changed')

    setTimeout(() => {
      newContentBlock.classList.remove('-highlight-changed')
    }, 2000)

    if (previousContentBlockId) {
      $(previousContentBlockSection).after(newContentBlock)
    } else {
      $(".js-projekt-content-block-edit-section").remove();
      $('.custom-page-content').append(newContentBlock);
    }

    setTimeout(() => {
      newContentBlock.scrollIntoView({ block: "center" })
      $(newContentBlock).find('.projekt-content-block').foundation();
      App.ImageGallery.initialize();
    }, 0)

    ProjektStudio.utils.sendMessageToDtParentFrame("createContentBlock",  {
      previous_content_block_id: previousContentBlockId,
      draft_content_block_index: draftContentBlockIndex,
      enter_ai_mode: contentTemplate.dataset.enterAiMode,
      html: contentTemplate.innerHTML
    });
  },

  enterTextEditMode(e) {
    const { contentBlockSection, contentBlock } = this.getContentBlockAndSection(e.target)

    contentBlockSection.classList.remove("-highlight-changed")
    contentBlockSection.classList.add("-text-edit-mode")
    $accordion = $(contentBlock).find('.accordion a');
    $accordion.off("keydown")

    this.toggleContentEditableForContentBlock(contentBlock, true)
    this.storePreviousVersionOfContentBlock(contentBlock, contentBlockSection)
  },

  enterHtmlEditMode(e) {
    const { contentBlockSection, contentBlock } = this.getContentBlockAndSection(e.target)

    contentBlockSection.classList.remove("-highlight-changed")
    contentBlockSection.classList.add("-html-edit-mode")
    this.storePreviousVersionOfContentBlock(contentBlock, contentBlockSection)

    contentBlock.innerHTML = `
      <textarea
        name="body"
        id="${this.genTextEditorIdForTextarea(contentBlockSection.dataset.contentBlockId)}"
        rows="8"
        class="html-area extended-a"
        style="visibility: hidden; display: none;"
      >
         ${contentBlock.innerHTML}
      </textarea>
    `

    App.HTMLEditor.enableCKeditorFor(contentBlock.querySelector("textarea"))
  },

  enterCodeEditMode(e) {
    const { contentBlockSection, contentBlock } = this.getContentBlockAndSection(e.target)

    contentBlockSection.classList.remove("-highlight-changed")
    contentBlockSection.classList.add("-code-edit-mode")
    this.storePreviousVersionOfContentBlock(contentBlock, contentBlockSection)

    contentBlock.innerHTML = `
      <textarea
        name="body"
        rows="8"
        style="visibility: hidden; display: none;">
         ${contentBlock.innerHTML}
      </textarea>
    `

    const textarea = contentBlockSection.querySelector("textarea[name='content']")
    const scopedToContentBlockEditorName = this.getCodeEditorName(contentBlockSection)
    let editor = this.aceInstances[scopedToContentBlockEditorName];

    if (!editor) {
      editor = ace.edit(textarea)
      this.aceInstances[scopedToContentBlockEditorName] = editor

      editor.setFontSize(14)
      editor.session.setMode("ace/mode/html");

      // editor.session.on('change', () => {
        // this.resizeEditorOnContentChange(editor)
      // });
    }

    const currentHTML = contentBlock.dataset.previousContentBlockHtml

    editor.setValue(currentHTML, currentHTML.length)
    editor.focus()
  },

  getCodeEditorName(container) {
    const contentBlockId = container.dataset.contentBlockId
    return `content-block-${contentBlockId}`
  },

  genTextEditorIdForTextarea(contentBlockId) {
    return `content-block-html-editor-${contentBlockId}`
  },

  toggleContentEditableForContentBlock(contentBlock, contentEditable) {
    const elements = Array.from(contentBlock.querySelectorAll("h2, h3, h4, p, a, .accordion-content, .js-text-editable"))

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
        focusContentEditableElement(contentBlock)
      }
      else {
        contentBlock.removeAttribute("contenteditable")
      }
    }
    else {
      const lastElement = elements[elements.length - 1]
      focusContentEditableElement(lastElement)
    }
  },

  handleSaveContentBlockEditedTextShortcut(e) {
    if (e.key === "Enter" && (e.metaKey || e.ctrlKey)) {
      this.saveContentBlockEditedText(e);
    }
  },

  saveContentBlockEditedText(e) {
    const { contentBlockSection, contentBlock} = this.getContentBlockAndSection(e.target);

    if (contentBlockSection.classList.contains("-text-edit-mode")) {
      contentBlockSection.classList.remove("-text-edit-mode")
      this.toggleContentEditableForContentBlock(contentBlock, false);

      this.saveContentBlock(
        contentBlock,
        contentBlockSection.dataset.contentBlockId,
        contentBlock.innerHTML.trim()
      )
    }
  },

  saveContentBlockEditedHtml(e) {
    const { contentBlockSection, contentBlock} = this.getContentBlockAndSection(e.target);

    if (contentBlockSection.classList.contains("-html-edit-mode")) {
      contentBlockSection.classList.remove("-html-edit-mode")

      const editorId = this.genTextEditorIdForTextarea(contentBlockSection.dataset.contentBlockId)

      let newContent = window.CKeditorInstancesGlobal[editorId].getData().trim()
      newContent = this.removeWrappingParagraphsFromCkeditorHtml(newContent)

      this.saveContentBlock(
        contentBlock,
        contentBlockSection.dataset.contentBlockId,
        newContent
      )
    }
  },

  saveContentBlock(contentBlock, contentBlockId, newContent) {
    const newContentBlock = ProjektStudio.utils.htmlToDomElement(newContent);

    resetFoundationAccordionStateFor(newContentBlock)

    ProjektStudio.utils.sendMessageToDtParentFrame("updateContentBlock", {
      content_block_id: contentBlockId,
      html: newContentBlock.innerHTML
    })

    // HACK to make Foundation re-initialization work for accorions and other foundation ui elements
    contentBlock.innerHTML = newContentBlock.innerHTML;
    $(contentBlock).foundation();
  },

  getContentBlockAndSection(element) {
    const contentBlockSection = this.findParentContentBlockSection(element)
    const contentBlock = contentBlockSection.querySelector(".projekt-content-block")

    return { contentBlockSection, contentBlock};
  },

  cancelTextEditMode(e) {
    const { contentBlockSection, contentBlock} = this.getContentBlockAndSection(e.target);

    contentBlockSection.classList.remove("-text-edit-mode")
    contentBlock.innerHTML = contentBlock.dataset.previousContentBlockHtml;
    this.toggleContentEditableForContentBlock(contentBlock, false);

    $(contentBlock).foundation();
  },

  cancelHtmlEditMode(e) {
    const { contentBlockSection, contentBlock} = this.getContentBlockAndSection(e.target);

    contentBlockSection.classList.remove("-html-edit-mode")
    contentBlock.innerHTML = contentBlock.dataset.previousContentBlockHtml;

    $(contentBlock).foundation();
  },

  cancelAiEditMode(e) {
    const { contentBlockSection } = this.getContentBlockAndSection(e.target);

    contentBlockSection.classList.remove("-ai-edit-mode")
  },

  storePreviousVersionOfContentBlock(contentBlock, contentBlockSection) {
    contentBlock.dataset.previousContentBlockHtml = contentBlock.innerHTML.trim();
    const returnToPrevButton = contentBlockSection.querySelector(".js-content-block-reset-to-prev-version")

    returnToPrevButton.disabled = false
  },

  resetPreviosVersionOfContentBlock(contentBlock, contentBlockSection) {
    contentBlock.dataset.previousContentBlockHtml = null;
    contentBlockSection.scrollIntoView({block: "center"});
    const returnToPrevButton = contentBlockSection.querySelector(".js-content-block-reset-to-prev-version")

    returnToPrevButton.disabled = true
  },

  resetToPreviousVersion(e) {
    const confirmed = confirm("Möchten Sie die letzte Änderung wirklich zurücksetzen?")

    if (confirmed) {
      const { contentBlock, contentBlockSection } = this.getContentBlockAndSection(e.target);

      if (contentBlock.dataset.previousContentBlockHtml) {
        contentBlock.innerHTML = contentBlock.dataset.previousContentBlockHtml;
        this.resetPreviosVersionOfContentBlock(contentBlock, contentBlockSection)

        ProjektStudio.utils.sendMessageToDtParentFrame("updateContentBlock", {
          content_block_id: contentBlockSection.dataset.contentBlockId,
          html: contentBlock.innerHTML
        })

        $(contentBlock).foundation();
      }
    }
  },

  signinWithToken(params) {
    $.ajax({
      type: "post",
      url: "iframe_sessions",
      data: {
        frame_sign_in_token: params.frame_sign_in_token,
        redirect_to: params.redirect_to
      }}
    )
  },

  handleOpenAdminPage(event) {
    event.preventDefault()
    history.pushState({}, '', window.location.href);

    const path = event.currentTarget.dataset.path;

    ProjektStudio.utils.sendMessageToDtParentFrame("Dt.openAdminPage", { path })
  },

   removeWrappingParagraphsFromCkeditorHtml(html) {
    const tempDiv = document.createElement('div');
    tempDiv.innerHTML = html;

    // Remove <p> tags wrapping only <a> elements
    tempDiv.querySelectorAll('ul.accordion p').forEach(p => {
      if (p.childNodes.length === 1 && p.firstChild.tagName === 'A') {
        p.replaceWith(p.firstChild); // Replace <p> with the <a> itself
      }
    });

    tempDiv.querySelectorAll('br[data-cke-filler="true"], br[data-cke-filler="false"]').forEach(br => {
      br.parentElement.remove()
    });

    return tempDiv.innerHTML;
  }
};

// export default ContentBlocks
