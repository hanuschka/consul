(function() {
  "use strict";
  App.HTMLEditor = {
    initialize: function() {
      var {
        ClassicEditor
      } = CKEDITOR;

      document.querySelectorAll( 'textarea.html-area' ).forEach( textarea => {
        ClassicEditor.create(textarea, {
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

          simpleUpload: {
            uploadUrl: '/ckeditor/pictures',
            withCredentials: true,
            headers: {
              'X-CSRF-TOKEN': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
            }
          },

          extraPlugins: [
            function ( editor ) {
              // Allow <iframe> elements in the model.
              editor.model.schema.register( 'iframe', {
                allowWhere: '$text',
                allowContentOf: '$block'
              } );
              // Allow <iframe> elements in the model to have all attributes.
              editor.model.schema.addAttributeCheck( context => {
                if ( context.endsWith( 'iframe' ) ) {
                  return true;
                }
              } );
              // View-to-model converter converting a view <iframe> with all its attributes to the model.
              editor.conversion.for( 'upcast' ).elementToElement( {
                view: 'iframe',
                model: ( viewElement, modelWriter ) => {
                  return modelWriter.writer.createElement( 'iframe', viewElement.getAttributes() );
                }
              } );
              // Model-to-view converter for the <iframe> element (attributes are converted separately).
              editor.conversion.for( 'downcast' ).elementToElement( {
                model: 'iframe',
                view: 'iframe'
              } );
              // Model-to-view converter for <iframe> attributes.
              // Note that a lower-level, event-based API is used here.
              editor.conversion.for( 'downcast' ).add( dispatcher => {
                dispatcher.on( 'attribute', ( evt, data, conversionApi ) => {
                  // Convert <iframe> attributes only.
                  if ( data.item.name != 'iframe' ) {
                    return;
                  }
                  const viewWriter = conversionApi.writer;
                  const viewIframe = conversionApi.mapper.toViewElement( data.item );
                  // In the model-to-view conversion we convert changes.
                  // An attribute can be added or removed or changed.
                  // The below code handles all 3 cases.
                  if ( data.attributeNewValue ) {
                    viewWriter.setAttribute( data.attributeKey, data.attributeNewValue, viewIframe );
                  } else {
                    viewWriter.removeAttribute( data.attributeKey, viewIframe );
                  }
                });
              });
            },
          ],
        })
      });
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
        SourceEditing
      } = CKEDITOR;

      if ( $(element).hasClass("extended-u") ) {

        plugins = [
          Essentials, Font, Paragraph,
          List, Indent, IndentBlock, BlockQuote, Alignment,
          Link, Bold, Italic, Underline, Strikethrough, Subscript, Superscript, RemoveFormat,
          Table, HorizontalLine, SpecialCharacters, SpecialCharactersEssentials
        ]

        toolbarControls = [
          "bulletedList", "numberedList", "|", "indent", "outdent", "|", "blockQuote", "|", "alignment:left", "alignment:center", "alignment:right", "alignment:justify", "|",
          "link", "|", "bold", "italic", "underline", "strikethrough", "subscript", "superscript", "|", "removeFormat", "|",
          "fontColor", "fontBackgroundColor", "|",
          "insertTable", "horizontalLine", "specialCharacters"
        ]

      } else if ( $(element).hasClass("extended-a") ) {

        plugins = [
          Essentials, Font, Paragraph,
          List, Indent, IndentBlock, BlockQuote, Alignment,
          ImageBlock, ImageCaption, ImageInline, ImageInsert, ImageResize, ImageStyle, ImageTextAlternative, ImageToolbar, ImageUpload, SimpleUploadAdapter,
          Link, Bold, Italic, Underline, Strikethrough, Subscript, Superscript, RemoveFormat,
          Table, HorizontalLine, SpecialCharacters, SpecialCharactersEssentials,
          MediaEmbed, SourceEditing
        ]

        toolbarControls = [
          "bulletedList", "numberedList", "|", "indent", "outdent", "|", "blockQuote", "|", "alignment:left", "alignment:center", "alignment:right", "alignment:justify", "|",
          "insertImage", "|",
          "link", "|", "bold", "italic", "underline", "strikethrough", "subscript", "superscript", "|", "removeFormat", "|",
          "fontColor", "fontBackgroundColor", "|",
          "insertTable", "horizontalLine", "specialCharacters", "|",
          "mediaEmbed", "sourceEditing"
        ]

      } else {
        plugins = [Essentials,Font, Paragraph, Bold, Italic]
        toolbarControls = ["bold", "italic"]
      }

      return { plugins: plugins, toolbarControls: toolbarControls }
    }
  };
}).call(this);
