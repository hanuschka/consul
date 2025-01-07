(function() {
  "use strict";

  window.CKeditorInstancesGlobal = {};

  function removeWrappingParagraphs(html) {
    const tempDiv = document.createElement('div');
    tempDiv.innerHTML = html;

    // Remove <p> tags wrapping only <a> elements
    tempDiv.querySelectorAll('ul.accordion p').forEach(p => {
      if (p.childNodes.length === 1 && p.firstChild.tagName === 'A') {
        p.replaceWith(p.firstChild); // Replace <p> with the <a> itself
      }
    });

    return tempDiv.innerHTML;
  }

  App.HTMLEditor = {
    initialize: function() {
      document.querySelectorAll('textarea.html-area').forEach(textarea => {
        this.enableCKeditorFor(textarea)
      });
    },

    enableCKeditorFor: function(textarea) {
      var { ClassicEditor } = CKEDITOR;

      var editorPromise =ClassicEditor.create(textarea, {
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
        window.CKeditorInstancesGlobal[editor.sourceElement.id] = editor;

        if (editor.sourceElement.form) {
          editor.sourceElement.form.addEventListener("submit", function(e) {
            e.preventDefault();

            var textarea = editor.sourceElement
            var editorData = editor.getData();
            var processedData = removeWrappingParagraphs(editorData);

            textarea.value = processedData
            textarea.form.submit();
          })
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
        ImageUpload,
        SimpleUploadAdapter,
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
          "heading", "|", "link", "|", "bold", "italic", "underline", "strikethrough", "subscript", "superscript", "|", "removeFormat", "|",
          "fontColor", "fontBackgroundColor", "|",
          "insertTable", "horizontalLine", "specialCharacters"
        ]

      } else if ( $(element).hasClass("extended-a") ) {

        plugins = [
          Essentials, Font, Paragraph, Heading,
          List, Indent, IndentBlock, BlockQuote, Alignment,
          ImageBlock, ImageCaption, ImageInline, ImageInsert, ImageResize, ImageStyle, ImageTextAlternative, ImageToolbar, ImageUpload, SimpleUploadAdapter,
          Link, Bold, Italic, Underline, Strikethrough, Subscript, Superscript, RemoveFormat,
          Table, HorizontalLine, SpecialCharacters, SpecialCharactersEssentials,
          MediaEmbed, SourceEditing,
          HtmlEmbed, GeneralHtmlSupport,
          window.UploadFilesPlugin
        ]

        toolbarControls = [
          "bulletedList", "numberedList", "|", "indent", "outdent", "|", "blockQuote", "|", "alignment:left", "alignment:center", "alignment:right", "alignment:justify", "|",
          "insertImage", "|",
          "heading", "|", "link", "|", "bold", "italic", "underline", "strikethrough", "subscript", "superscript", "|", "removeFormat", "|",
          "fontColor", "fontBackgroundColor", "|",
          "insertTable", "horizontalLine", "specialCharacters", "|",
          "mediaEmbed", "sourceEditing", "|",
          "htmlEmbed",
          "uploadFiles"
        ]

      } else {
        plugins = [Essentials,Font, Paragraph, Bold, Italic]
        toolbarControls = ["bold", "italic"]
      }

      return { plugins: plugins, toolbarControls: toolbarControls }
    }
  };
}).call(this);
