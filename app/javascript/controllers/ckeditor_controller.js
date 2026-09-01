import { Controller } from "@hotwired/stimulus"
import * as CKEditorModule from "../ckeditor5/ckeditor5.umd"
import { createUploadFilesPlugin } from "../ckeditor5/file-upload-plugin"

const CKEDITOR = CKEditorModule.default || CKEditorModule
window.CKEDITOR = CKEDITOR

const UploadFilesPlugin = createUploadFilesPlugin(CKEDITOR)
window.UploadFilesPlugin = UploadFilesPlugin

function removeWrappingParagraphs(html) {
  const tempDiv = document.createElement("div")
  tempDiv.innerHTML = html

  function hasSingleChildOfType(node, tag) {
    if (node.childNodes.length !== 1) return false
    const child = node.firstElementChild
    return child && child.tagName === tag.toUpperCase()
  }

  tempDiv.querySelectorAll("ul.accordion p").forEach(p => {
    if (hasSingleChildOfType(p, "a")) {
      p.replaceWith(p.firstElementChild)
    }
  })

  tempDiv.querySelectorAll("div").forEach(div => {
    const nonEmptyChildren = Array.from(div.childNodes).filter(node => {
      return !(node.nodeType === Node.TEXT_NODE && !node.textContent.trim())
    })

    if (
      nonEmptyChildren.length === 1 &&
      nonEmptyChildren[0].nodeType === Node.ELEMENT_NODE &&
      nonEmptyChildren[0].tagName === "BR"
    ) {
      div.replaceWith(nonEmptyChildren[0])
    }
  })

  return tempDiv.innerHTML
}

// Custom plugin to process HTML output
class RemoveWrappingParagraphsPlugin extends CKEDITOR.Plugin {
  static get pluginName() {
    return "RemoveWrappingParagraphsPlugin"
  }

  init() {
    const editor = this.editor
    editor.data.processor.originalToView = editor.data.processor.toView
    editor.data.processor.toView = data => {
      return editor.data.processor.originalToView(data)
    }
    editor.data.processor.originalToData = editor.data.processor.toData
    editor.data.processor.toData = viewFragment => {
      const data = editor.data.processor.originalToData(viewFragment)
      return removeWrappingParagraphs(data)
    }
  }
}

export default class extends Controller {
  static values = {
    toolbar: { type: String, default: "regular" }
  }

  connect() {
    this.initializeEditor()
  }

  disconnect() {
    if (this.editor) {
      this.editor.destroy()
      this.editor = null
    }
  }

  initializeEditor() {
    const { ClassicEditor } = CKEDITOR
    const { plugins, toolbarControls } = this.toolbarConfig()

    const editorPromise = ClassicEditor.create(this.element, {
      plugins,
      toolbar: {
        items: toolbarControls,
        shouldNotGroupWhenFull: true
      },

      image: {
        toolbar: [
          "toggleImageCaption",
          "imageTextAlternative",
          "|",
          "imageStyle:inline",
          "imageStyle:wrapText",
          "imageStyle:breakText",
          "|",
          "resizeImage"
        ],
        upload: {
          types: ["jpg", "jpeg", "png", "gif"]
        }
      },

      fontSize: {
        options: [9, 11, "default", 17, 19, 21]
      },

      heading: {
        options: [
          { model: "paragraph", title: "Paragraph", class: "ck-heading_paragraph" },
          { model: "heading1", view: "h1", title: "Heading 1", class: "ck-heading_heading1" },
          { model: "heading2", view: "h2", title: "Heading 2", class: "ck-heading_heading2" },
          { model: "heading3", view: "h3", title: "Heading 3", class: "ck-heading_heading3" },
          { model: "heading4", view: "h4", title: "Heading 4", class: "ck-heading_heading4" },
          { model: "heading5", view: "h5", title: "Heading 5", class: "ck-heading_heading5" },
          { model: "heading6", view: "h6", title: "Heading 6", class: "ck-heading_heading6" }
        ]
      },

      simpleUpload: {
        uploadUrl: "/ckeditor/pictures",
        withCredentials: true,
        headers: {
          "X-CSRF-TOKEN": document.querySelector('meta[name="csrf-token"]')?.getAttribute("content")
        }
      },

      htmlSupport: {
        allow: [{ name: /.*/, attributes: true, classes: true, styles: true }]
      },

    })

    editorPromise.then(editor => {
      this.editor = editor

      if (this.element.disabled) {
        editor.enableReadOnlyMode("source-element-disabled")
      }

      // DO NOT DELETE
      // IMPORTANT: it's used in projekt studio for content blocks
      window.App = window.App || {}
      window.App.HTMLEditor = window.App.HTMLEditor || { instances: {} }
      window.App.HTMLEditor.instances[editor.sourceElement.id] = editor

      if (editor.sourceElement.classList.contains("js-user-resource-form-description")) {
        window.App.HTMLEditor.instances["userResourceFromEditor"] = editor
      }
    })
  }

  toolbarConfig() {
    const {
      ImageBlock, ImageCaption, ImageInline, ImageInsert, ImageResize,
      ImageStyle, ImageTextAlternative, ImageToolbar,
      Essentials, Font, Paragraph, Heading,
      List, Indent, IndentBlock, BlockQuote, Alignment,
      Link, Bold, Italic, Underline, Strikethrough, Subscript, Superscript,
      RemoveFormat,
      Table, HorizontalLine, SpecialCharacters, SpecialCharactersEssentials,
      MediaEmbed, SourceEditing, HtmlEmbed, GeneralHtmlSupport
    } = CKEDITOR

    if (this.toolbarValue === "extended-u") {
      return {
        plugins: [
          Essentials, Font, Paragraph, Heading,
          List, Indent, IndentBlock, BlockQuote, Alignment,
          Link, Bold, Italic, Underline, Strikethrough, Subscript, Superscript, RemoveFormat,
          Table, HorizontalLine, SpecialCharacters, SpecialCharactersEssentials,
          RemoveWrappingParagraphsPlugin
        ],
        toolbarControls: [
          "bulletedList", "numberedList", "|", "indent", "outdent", "|", "blockQuote", "|",
          "alignment:left", "alignment:center", "alignment:right", "alignment:justify", "|",
          "heading", "|", "link", "|", "bold", "italic", "underline", "|",
          "fontColor", "fontBackgroundColor", "|",
          "insertTable", "horizontalLine"
        ]
      }
    } else if (this.toolbarValue === "extended-a") {
      return {
        plugins: [
          Essentials, Font, Paragraph, Heading,
          List, Indent, IndentBlock, BlockQuote, Alignment,
          ImageBlock, ImageCaption, ImageInline, ImageInsert, ImageResize,
          ImageStyle, ImageTextAlternative, ImageToolbar, UploadFilesPlugin,
          Link, Bold, Italic, Underline, Strikethrough, Subscript, Superscript, RemoveFormat,
          Table, HorizontalLine, SpecialCharacters, SpecialCharactersEssentials,
          MediaEmbed, SourceEditing, HtmlEmbed, GeneralHtmlSupport,
          RemoveWrappingParagraphsPlugin
        ],
        toolbarControls: [
          "bulletedList", "numberedList", "|", "indent", "outdent", "|", "blockQuote", "|",
          "alignment:left", "alignment:center", "alignment:right", "alignment:justify", "|",
          "fontSize", "|",
          "heading", "|", "link", "|", "bold", "italic", "underline", "|",
          "fontColor", "fontBackgroundColor", "|",
          "insertTable", "horizontalLine", "|",
          "mediaEmbed", "sourceEditing", "|",
          "htmlEmbed", "uploadFiles"
        ]
      }
    } else if (this.toolbarValue === "email") {
      return {
        plugins: [
          Essentials, Font, Paragraph, Heading,
          List, Alignment,
          ImageBlock, ImageCaption, ImageInline, ImageInsert, ImageResize,
          ImageStyle, ImageTextAlternative, ImageToolbar, UploadFilesPlugin,
          Link, Bold, Italic, Underline, RemoveFormat,
          HorizontalLine, SourceEditing, GeneralHtmlSupport,
          RemoveWrappingParagraphsPlugin
        ],
        toolbarControls: [
          "bold", "italic", "underline", "|",
          "link", "|",
          "heading", "|",
          "bulletedList", "numberedList", "|",
          "alignment:left", "alignment:center", "alignment:right", "|",
          "fontColor", "|",
          "horizontalLine", "|",
          "uploadFiles", "|",
          "sourceEditing"
        ]
      }
    } else {
      return {
        plugins: [Essentials, Font, Paragraph, Bold, Italic, RemoveWrappingParagraphsPlugin],
        toolbarControls: ["bold", "italic"]
      }
    }
  }
}
