(function() {
  "use strict";

  App.HTMLEditor = {
    // DO NOT DELETE
    // IMPORTANT: it's used in projekt studio for content blocks
    instances: {},

    initialize: function() {
      document.querySelectorAll('textarea.html-area').forEach(textarea => {
        this.enableCKeditorFor(textarea)
      });
    },

    destroy: function() {
      Object.keys(this.instances).forEach(key => {
        const editor = this.instances[key];

        if (editor && editor.destroy) {
          editor.destroy().catch(() => {});
        }
      });

      this.instances = {};
    },

    enableCKeditorFor: function(textarea) {
      var { ClassicEditor } = CKEDITOR;

      var editorPromise = ClassicEditor.create(textarea, {
        plugins: this.toolbarFor(textarea).plugins,
        toolbar: {
          items: this.toolbarFor(textarea).toolbarControls,
          shouldNotGroupWhenFull: true
        },

        image: {
          toolbar: [
            'toggleImageCaption',
            'imageTextAlternative',
            '|',
            'imageStyle:inline',
            'imageStyle:wrapText',
            'imageStyle:breakText',
            '|',
            'resizeImage'
          ],
          upload: {
            types: ['jpg', 'jpeg', 'png', 'gif']
          }
        },

        fontSize: {
            options: [
                9,
                11,
                'default',
                17,
                19,
                21
            ]
        },

        heading: {
          options: [
            {
              model: 'paragraph',
              title: 'Paragraph',
              class: 'ck-heading_paragraph'
            },
            {
              model: 'heading1',
              view: 'h1',
              title: 'Heading 1',
              class: 'ck-heading_heading1'
            },
            {
              model: 'heading2',
              view: 'h2',
              title: 'Heading 2',
              class: 'ck-heading_heading2'
            },
            {
              model: 'heading3',
              view: 'h3',
              title: 'Heading 3',
              class: 'ck-heading_heading3'
            },
            {
              model: 'heading4',
              view: 'h4',
              title: 'Heading 4',
              class: 'ck-heading_heading4'
            },
            {
              model: 'heading5',
              view: 'h5',
              title: 'Heading 5',
              class: 'ck-heading_heading5'
            },
            {
              model: 'heading6',
              view: 'h6',
              title: 'Heading 6',
              class: 'ck-heading_heading6'
            }
          ]
        },

        simpleUpload: {
          uploadUrl: '/ckeditor/pictures',
          withCredentials: true,
          headers: {
            'X-CSRF-TOKEN': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
          }
        },

        htmlSupport: {
          allow: [
            {
              name: /.*/,
              attributes: true,
              classes: true,
              styles: true
            }
          ]
        },

        extraPlugins: [
          function(editor) {
            editor.data.processor.originalToView =  editor.data.processor.toView;
            editor.data.processor.toView = (data) => {
              const viewFragment = editor.data.processor.originalToView(data);

              var domFragment = editor.data.processor.domConverter.viewToDom( viewFragment );
              // var viewFragmentData =  editor.data.processor.htmlWriter.getHtml( domFragment );

              return viewFragment;
            };
            editor.data.processor.originalToData =  editor.data.processor.toData;
            editor.data.processor.toData = (viewFragment) => {
              var data = editor.data.processor.originalToData(viewFragment)
              data = removeWrappingParagraphs(data);
              return data
            };
          },
        ],
      })

      editorPromise.then((editor) => {
        // DO NOT DELETE
        // IMPORTANT: it's used in projekt studio for content blocks
        App.HTMLEditor.instances[editor.sourceElement.id] = editor;

        if (editor.sourceElement.classList.contains("js-user-resource-form-description")) {
          App.HTMLEditor.instances["userResourceFromEditor"] = editor;
        }
      })
    },

    toolbarFor: function(element) {

      var toolbarControls, plugins;
      var {
        ImageBlock,
        ImageCaption,
        ImageInline,
        ImageInsert,
        ImageInsertViaUrl,
        ImageResize,
        ImageStyle,
        ImageTextAlternative,
        ImageToolbar,
        ClassicEditor,
        Essentials,
        Font,
        Paragraph,
        Heading,
        List,
        Indent,
        IndentBlock,
        BlockQuote,
        Alignment,
        Link,
        Bold,
        Italic,
        Underline,
        Strikethrough,
        Subscript,
        Superscript,
        RemoveFormat,
        FontColor,
        FontBackgroundColor,
        Table,
        HorizontalLine,
        SpecialCharacters,
        SpecialCharactersEssentials,
        MediaEmbed,
        SourceEditing,
        HtmlEmbed,
        GeneralHtmlSupport,
      } = CKEDITOR;

      if ( $(element).hasClass("extended-u") ) {
        plugins = [
          Essentials, Font, Paragraph, Heading,
          List, Indent, IndentBlock, BlockQuote, Alignment,
          Link, Bold, Italic, Underline, Strikethrough, Subscript, Superscript, RemoveFormat,
          Table, HorizontalLine, SpecialCharacters, SpecialCharactersEssentials
        ]

        toolbarControls = [
          "bulletedList", "numberedList", "|", "indent", "outdent", "|", "blockQuote", "|", "alignment:left", "alignment:center", "alignment:right", "alignment:justify", "|",
          "heading", "|", "link", "|", "bold", "italic", "underline", "|",
          "fontColor", "fontBackgroundColor", "|",
          "insertTable", "horizontalLine"
        ]

      } else if ( $(element).hasClass("extended-a") ) {

        plugins = [
          Essentials, Font, Paragraph, Heading,
          List, Indent, IndentBlock, BlockQuote, Alignment,
          ImageBlock, ImageCaption, ImageInline, ImageInsert, ImageResize, ImageStyle, ImageTextAlternative, ImageToolbar, window.UploadFilesPlugin,
          Link, Bold, Italic, Underline, Strikethrough, Subscript, Superscript, RemoveFormat,
          Table, HorizontalLine, SpecialCharacters, SpecialCharactersEssentials,
          MediaEmbed, SourceEditing,
          HtmlEmbed, GeneralHtmlSupport
        ]

        toolbarControls = [
          "bulletedList", "numberedList", "|", "indent", "outdent", "|", "blockQuote", "|", "alignment:left", "alignment:center", "alignment:right", "alignment:justify", "|",
          "|", "fontSize", "|",
          "heading", "|", "link", "|", "bold", "italic", "underline", "|",
          "fontColor", "fontBackgroundColor", "|",
          "insertTable", "horizontalLine","|",
          "mediaEmbed", "sourceEditing", "|",
          "htmlEmbed", "uploadFiles"
        ]

      } else {
        plugins = [Essentials,Font, Paragraph, Bold, Italic]
        toolbarControls = ["bold", "italic"]
      }

      return { plugins: plugins, toolbarControls: toolbarControls }
    }
  };

  function removeWrappingParagraphs(html) {
    const tempDiv = document.createElement('div');
    tempDiv.innerHTML = html;

    // Helper: check if element only contains a single element of a given tag
    function hasSingleChildOfType(node, tag) {
      if (node.childNodes.length !== 1) return false;
      const child = node.firstElementChild;
      return child && child.tagName === tag.toUpperCase();
    }

    // Remove <p> tags wrapping only <a> elements
    tempDiv.querySelectorAll('ul.accordion p').forEach(p => {
      if (hasSingleChildOfType(p, 'a')) {
        p.replaceWith(p.firstElementChild);
      }
    });

    // Replace <div> containing only <br> with <br>
    tempDiv.querySelectorAll('div').forEach(div => {
      // Trim out empty text nodes
      const nonEmptyChildren = Array.from(div.childNodes).filter(node => {
        return !(node.nodeType === Node.TEXT_NODE && !node.textContent.trim());
      });

      if (
        nonEmptyChildren.length === 1 &&
        nonEmptyChildren[0].nodeType === Node.ELEMENT_NODE &&
        nonEmptyChildren[0].tagName === 'BR'
      ) {
        div.replaceWith(nonEmptyChildren[0]);
      }
    });

    return tempDiv.innerHTML;
  }
}).call(this);
