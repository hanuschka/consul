"use strict";

function _typeof(o) { "@babel/helpers - typeof"; return _typeof = "function" == typeof Symbol && "symbol" == typeof Symbol.iterator ? function (o) { return typeof o; } : function (o) { return o && "function" == typeof Symbol && o.constructor === Symbol && o !== Symbol.prototype ? "symbol" : typeof o; }, _typeof(o); }
function ownKeys(e, r) { var t = Object.keys(e); if (Object.getOwnPropertySymbols) { var o = Object.getOwnPropertySymbols(e); r && (o = o.filter(function (r) { return Object.getOwnPropertyDescriptor(e, r).enumerable; })), t.push.apply(t, o); } return t; }
function _objectSpread(e) { for (var r = 1; r < arguments.length; r++) { var t = null != arguments[r] ? arguments[r] : {}; r % 2 ? ownKeys(Object(t), !0).forEach(function (r) { _defineProperty(e, r, t[r]); }) : Object.getOwnPropertyDescriptors ? Object.defineProperties(e, Object.getOwnPropertyDescriptors(t)) : ownKeys(Object(t)).forEach(function (r) { Object.defineProperty(e, r, Object.getOwnPropertyDescriptor(t, r)); }); } return e; }
function _defineProperty(e, r, t) { return (r = _toPropertyKey(r)) in e ? Object.defineProperty(e, r, { value: t, enumerable: !0, configurable: !0, writable: !0 }) : e[r] = t, e; }
function _toConsumableArray(r) { return _arrayWithoutHoles(r) || _iterableToArray(r) || _unsupportedIterableToArray(r) || _nonIterableSpread(); }
function _nonIterableSpread() { throw new TypeError("Invalid attempt to spread non-iterable instance.\nIn order to be iterable, non-array objects must have a [Symbol.iterator]() method."); }
function _unsupportedIterableToArray(r, a) { if (r) { if ("string" == typeof r) return _arrayLikeToArray(r, a); var t = {}.toString.call(r).slice(8, -1); return "Object" === t && r.constructor && (t = r.constructor.name), "Map" === t || "Set" === t ? Array.from(r) : "Arguments" === t || /^(?:Ui|I)nt(?:8|16|32)(?:Clamped)?Array$/.test(t) ? _arrayLikeToArray(r, a) : void 0; } }
function _iterableToArray(r) { if ("undefined" != typeof Symbol && null != r[Symbol.iterator] || null != r["@@iterator"]) return Array.from(r); }
function _arrayWithoutHoles(r) { if (Array.isArray(r)) return _arrayLikeToArray(r); }
function _arrayLikeToArray(r, a) { (null == a || a > r.length) && (a = r.length); for (var e = 0, n = Array(a); e < a; e++) n[e] = r[e]; return n; }
function _classCallCheck(a, n) { if (!(a instanceof n)) throw new TypeError("Cannot call a class as a function"); }
function _defineProperties(e, r) { for (var t = 0; t < r.length; t++) { var o = r[t]; o.enumerable = o.enumerable || !1, o.configurable = !0, "value" in o && (o.writable = !0), Object.defineProperty(e, _toPropertyKey(o.key), o); } }
function _createClass(e, r, t) { return r && _defineProperties(e.prototype, r), t && _defineProperties(e, t), Object.defineProperty(e, "prototype", { writable: !1 }), e; }
function _toPropertyKey(t) { var i = _toPrimitive(t, "string"); return "symbol" == _typeof(i) ? i : i + ""; }
function _toPrimitive(t, r) { if ("object" != _typeof(t) || !t) return t; var e = t[Symbol.toPrimitive]; if (void 0 !== e) { var i = e.call(t, r || "default"); if ("object" != _typeof(i)) return i; throw new TypeError("@@toPrimitive must return a primitive value."); } return ("string" === r ? String : Number)(t); }
function _callSuper(t, o, e) { return o = _getPrototypeOf(o), _possibleConstructorReturn(t, _isNativeReflectConstruct() ? Reflect.construct(o, e || [], _getPrototypeOf(t).constructor) : o.apply(t, e)); }
function _possibleConstructorReturn(t, e) { if (e && ("object" == _typeof(e) || "function" == typeof e)) return e; if (void 0 !== e) throw new TypeError("Derived constructors may only return object or undefined"); return _assertThisInitialized(t); }
function _assertThisInitialized(e) { if (void 0 === e) throw new ReferenceError("this hasn't been initialised - super() hasn't been called"); return e; }
function _isNativeReflectConstruct() { try { var t = !Boolean.prototype.valueOf.call(Reflect.construct(Boolean, [], function () {})); } catch (t) {} return (_isNativeReflectConstruct = function _isNativeReflectConstruct() { return !!t; })(); }
function _getPrototypeOf(t) { return _getPrototypeOf = Object.setPrototypeOf ? Object.getPrototypeOf.bind() : function (t) { return t.__proto__ || Object.getPrototypeOf(t); }, _getPrototypeOf(t); }
function _inherits(t, e) { if ("function" != typeof e && null !== e) throw new TypeError("Super expression must either be null or a function"); t.prototype = Object.create(e && e.prototype, { constructor: { value: t, writable: !0, configurable: !0 } }), Object.defineProperty(t, "prototype", { writable: !1 }), e && _setPrototypeOf(t, e); }
function _setPrototypeOf(t, e) { return _setPrototypeOf = Object.setPrototypeOf ? Object.setPrototypeOf.bind() : function (t, e) { return t.__proto__ = e, t; }, _setPrototypeOf(t, e); }
var _CKEDITOR = CKEDITOR,
  ClassicEditor = _CKEDITOR.ClassicEditor,
  Plugin = _CKEDITOR.Plugin,
  ButtonView = _CKEDITOR.ButtonView,
  icons = _CKEDITOR.icons,
  Dialog = _CKEDITOR.Dialog,
  View = _CKEDITOR.View,
  InputTextView = _CKEDITOR.InputTextView,
  ViewCollection = _CKEDITOR.ViewCollection;
var UploadFilesPlugin = /*#__PURE__*/function (_Plugin) {
  function UploadFilesPlugin(editor) {
    var _this;
    _classCallCheck(this, UploadFilesPlugin);
    _this = _callSuper(this, UploadFilesPlugin, [editor]);

    // Default state
    _this.url = ''; //https://demo.demokratie.today
    _this.apiGet = "".concat(_this.url, "/ckeditor/assets");
    _this.apiUpload = {
      picture: "".concat(_this.url, "/ckeditor/pictures"),
      document: "".concat(_this.url, "/ckeditor/documents")
    };
    _this.apiPut = function (id) {
      return "".concat(_this.url, "/ckeditor/pictures/").concat(id);
    };
    _this.fileAccept = {
      picture: 'image/*',
      document: ''
    };
    _this.csrf_token = document.querySelector('meta[name="csrf-token"]') ? document.querySelector('meta[name="csrf-token"]').content : 'test';
    _this.state = {
      editor_id: editor.sourceElement.id,
      type: 'picture',
      page: 1,
      search: '',
      total_pages: 0,
      items: [],
      chosen: {},
      isLoading: false
    };
    return _this;
  }

  // Make sure the "Dialog" plugin is loaded.
  _inherits(UploadFilesPlugin, _Plugin);
  return _createClass(UploadFilesPlugin, [{
    key: "requires",
    get: function get() {
      return [Dialog];
    }
  }, {
    key: "init",
    value: function init() {
      var _this2 = this;
      var editor = this.editor;

      // Add the "upload files" button to the toolbar.
      editor.ui.componentFactory.add('uploadFiles', function (locale) {
        var buttonView = new ButtonView(locale);
        buttonView.set({
          label: 'Dateien hochladen',
          icon: icons.browseFiles,
          tooltip: true
        });
        buttonView.on('execute', function () {
          var dialog = _this2.editor.plugins.get('Dialog');
          if (buttonView.isOn) {
            dialog.hide();
            buttonView.isOn = false;
            return;
          }
          buttonView.isOn = true;
          _this2._createDialogContent(locale);

          // Show the dialog with the generated content
          dialog.show({
            title: 'CkEditor-Dateien',
            content: _this2.dialogView,
            actionButtons: [{
              label: 'Wählen',
              "class": 'ck-button-action',
              withText: true,
              onExecute: function onExecute() {
                if (_this2.state.chosen.url) {
                  var _editor = _this2.editor;
                  var chosenItem = _this2.state.chosen;
                  if (chosenItem.data_content_type.startsWith('image/')) {
                    _editor.model.change(function (writer) {
                      var selection = _editor.model.document.selection;
                      var insertPosition = selection.getFirstPosition();
                      var canInsertImageBlock = _editor.model.schema.checkChild(insertPosition.parent, 'imageBlock');
                      var canInsertImageInline = _editor.model.schema.checkChild(insertPosition.parent, 'imageInline');
                      if (canInsertImageBlock) {
                        var imageBlockElement = writer.createElement('imageBlock', {
                          src: _this2.state.chosen.url,
                          alt: _this2.state.chosen.alt_text || 'Default alt text'
                        });
                        _editor.model.insertContent(imageBlockElement, insertPosition);
                        writer.setSelection(imageBlockElement, 'on');
                      } else if (canInsertImageInline) {
                        var imageInlineElement = writer.createElement('imageInline', {
                          src: _this2.state.chosen.url,
                          alt: _this2.state.chosen.alt_text || _this2.state.chosen.data_file_name
                        });
                        _editor.model.insertContent(imageInlineElement, insertPosition);
                        writer.setSelection(imageInlineElement, 'on');
                      } else {
                        var root = _editor.model.document.getRoot();
                        var fallbackPosition = writer.createPositionAt(root, 'end');
                        var fallbackImageBlockElement = writer.createElement('imageBlock', {
                          src: _this2.state.chosen.url,
                          alt: _this2.state.chosen.alt_text || _this2.state.chosen.data_file_name
                        });
                        _editor.model.insertContent(fallbackImageBlockElement, fallbackPosition);
                        writer.setSelection(fallbackImageBlockElement, 'on');
                      }
                    });
                  } else {
                    _editor.model.change(function (writer) {
                      var linkText = chosenItem.title || chosenItem.data_file_name || 'File';
                      var linkUrl = chosenItem.url;
                      var linkRange = writer.createText(linkText, {
                        linkHref: linkUrl
                      });
                      _editor.model.insertContent(linkRange, _editor.model.document.selection);
                    });
                  }
                }
                dialog.hide();
              }
            }],
            onHide: function onHide() {
              _this2.state = {
                type: 'picture',
                page: 1,
                search: '',
                total_pages: 0,
                items: [],
                chosen: {},
                isLoading: false
              };
              buttonView.isOn = false;
            }
          });

          // Fetch the initial files when the dialog opens
          _this2._fetchFiles({
            type: _this2.state.type,
            page: _this2.state.page,
            search: _this2.state.search
          });
        });
        return buttonView;
      });
    }

    // Creates the dialog content view
  }, {
    key: "_createDialogContent",
    value: function _createDialogContent(locale) {
      this.dialogView = new View(locale);
      this._createSidebar();
      var mainPanel = this._createMainPanel(locale);
      this.dialogView.setTemplate({
        tag: 'div',
        attributes: {
          style: {
            display: 'flex',
            flexDirection: 'column',
            whiteSpace: 'initial',
            width: '90vw',
            maxWidth: '800px'
          },
          "class": 'upldFls__wrapper ck-reset_all-excluded'
        },
        children: [{
          tag: 'div',
          attributes: {
            "class": 'upldFls__inner'
          },
          children: [this.sidebarView, mainPanel]
        }]
      });
    }
  }, {
    key: "_updateSidebarView",
    value: function _updateSidebarView() {
      this._createSidebar();
      if (this.sidebarView && this.sidebarView.isRendered === false) {
        this.sidebarView.render();
      }
      var sidebarContainer = this.dialogView.element.querySelector('.upldFls__inner > .ckbox-navbar');
      if (sidebarContainer) {
        sidebarContainer.replaceWith(this.sidebarView.element);
      }
    }
  }, {
    key: "_createSidebar",
    value: function _createSidebar() {
      var _this3 = this;
      this.sidebarView = new View(this.editor.locale);
      if (this.state.chosen && Object.keys(this.state.chosen).length > 0) {
        // Sidebar for the chosen item
        var chosenItem = this.state.chosen;
        var titleLabel = new View(this.editor.locale);
        titleLabel.setTemplate({
          tag: 'label',
          attributes: {
            "class": 'upldFls__details'
          },
          children: ['Title']
        });
        var titleInput = new InputTextView(this.editor.locale);
        titleInput.set({
          value: chosenItem.title,
          placeholder: 'Title',
          multiline: true
        });
        titleInput.bind('value').to(function () {
          return chosenItem.title;
        });
        titleInput.on('input', function (event) {
          _this3.state.chosen.title = event.source.element.value;
        });
        var descriptionLabel = new View(this.editor.locale);
        descriptionLabel.setTemplate({
          tag: 'label',
          attributes: {
            "class": 'upldFls__details'
          },
          children: ['Description']
        });
        var descriptionInput = new InputTextView(this.editor.locale);
        descriptionInput.set({
          value: chosenItem.description,
          placeholder: 'Beschreibung',
          multiline: true
        });
        descriptionInput.bind('value').to(function () {
          return chosenItem.description;
        });
        descriptionInput.on('input', function (event) {
          _this3.state.chosen.description = event.source.element.value;
        });
        var altTextLabel = new View(this.editor.locale);
        altTextLabel.setTemplate({
          tag: 'label',
          attributes: {
            "class": 'upldFls__details'
          },
          children: ['Alt Text']
        });
        var altTextInput = new InputTextView(this.editor.locale);
        altTextInput.set({
          value: chosenItem.alt_text,
          placeholder: 'Alt Text',
          multiline: true
        });
        altTextInput.bind('value').to(function () {
          return chosenItem.alt_text;
        });
        altTextInput.on('input', function (event) {
          _this3.state.chosen.alt_text = event.source.element.value;
        });
        var editButton = new ButtonView(this.editor.locale);
        editButton.set({
          label: 'Aktualisieren',
          withText: true,
          "class": 'upldFls__btnEdit'
        });
        this.listenTo(editButton, 'execute', function () {
          _this3._editFile();
        });

        //*********

        // Display chosen item details
        var fileName = new View(this.editor.locale);
        fileName.setTemplate({
          tag: 'p',
          attributes: {
            "class": 'upldFls__details'
          },
          children: ["Name: ".concat(chosenItem.data_file_name)]
        });
        var uploadDate = new View(this.editor.locale);
        uploadDate.setTemplate({
          tag: 'p',
          attributes: {
            "class": 'upldFls__details'
          },
          children: ["Upload Date: ".concat(chosenItem.created_at)]
        });
        var fileSize = new View(this.editor.locale);
        fileSize.setTemplate({
          tag: 'p',
          attributes: {
            "class": 'upldFls__details'
          },
          children: ["File Size: ".concat(parseInt(chosenItem.data_file_size / 1024), "kb")]
        });
        var fileDimensions = new View(this.editor.locale);
        if (chosenItem.width && chosenItem.height) {
          fileDimensions.setTemplate({
            tag: 'p',
            attributes: {
              "class": 'upldFls__details'
            },
            children: ["Dimensions: ".concat(chosenItem.width, " x ").concat(chosenItem.height)]
          });
        }

        // *******

        var deleteButton = new ButtonView(this.editor.locale);
        deleteButton.set({
          label: 'Löschen',
          withText: true,
          "class": 'upldFls__btnDelete'
        });
        this.listenTo(deleteButton, 'execute', function () {
          _this3._deleteFile();
        });
        this.sidebarView.setTemplate({
          tag: 'div',
          attributes: {
            "class": 'ckbox-navbar upldFls__navbar'
          },
          children: [{
            tag: 'div',
            attributes: {
              "class": 'upldFls__editForm'
            },
            children: [titleLabel, titleInput, descriptionLabel, descriptionInput, altTextLabel, altTextInput, editButton]
          }, {
            tag: 'div',
            attributes: {
              "class": 'upldFls__metaData'
            },
            children: [fileName, uploadDate, fileSize].concat(_toConsumableArray(chosenItem.width && chosenItem.height ? [fileDimensions] : []))
          }, {
            tag: 'div',
            attributes: {
              "class": 'upldFls__editForm'
            },
            children: [deleteButton]
          }]
        });
      } else {
        var imageButton = new ButtonView(this.editor.locale);
        imageButton.set({
          label: 'Bilder',
          tooltip: true,
          withText: true,
          "class": "upldFls__btn ".concat(this.state.type === 'picture' ? 'active' : '')
        });
        this.listenTo(imageButton, 'execute', function () {
          _this3._handleTypeClick('picture');
          updateButtonClasses();
        });

        // Create the documents button
        var documentsButton = new ButtonView(this.editor.locale);
        documentsButton.set({
          label: 'Dokumente',
          tooltip: true,
          withText: true,
          "class": "upldFls__btn ".concat(this.state.type === 'document' ? 'active' : '')
        });
        this.listenTo(documentsButton, 'execute', function () {
          _this3._handleTypeClick('document');
          updateButtonClasses();
        });

        // Update button classes dynamically based on state
        var updateButtonClasses = function updateButtonClasses() {
          if (_this3.state.type === 'picture' && imageButton.element) {
            imageButton.element.classList.add('active');
            documentsButton.element.classList.remove('active');
          } else if (_this3.state.type === 'document' && documentsButton.element) {
            documentsButton.element.classList.add('active');
            imageButton.element.classList.remove('active');
          }
        };

        // Call updateButtonClasses initially and whenever the type changes
        updateButtonClasses();

        //this.listenTo(this, 'change:type', updateButtonClasses);

        // Create the search input
        var searchInput = new InputTextView(this.editor.locale);
        searchInput.set({
          value: this.state.search,
          placeholder: 'Suchen...'
        });
        searchInput.bind('value').to(function () {
          return _this3.state.search;
        });
        searchInput.on('input', function (event) {
          _this3.state.search = event.source.element.value;
        });

        // Create the search button
        var searchButton = new ButtonView(this.editor.locale);
        searchButton.set({
          label: 'Suchen',
          icon: icons.search,
          tooltip: true,
          withText: true,
          "class": 'upldFls__searchBtn'
        });
        this.listenTo(searchButton, 'execute', function () {
          _this3._handleSearchSubmit();
        });

        // Create the upload button
        var imageUploadButton = new ButtonView(this.editor.locale);
        imageUploadButton.set({
          label: 'Upload files',
          icon: icons.importExport,
          tooltip: true,
          withText: true,
          "class": 'upldFls__btnUpload'
        });
        this.listenTo(imageUploadButton, 'execute', function () {
          var fileInput = document.createElement('input');
          fileInput.type = 'file';
          fileInput.accept = _this3.fileAccept[_this3.state.type];
          fileInput.click();
          fileInput.addEventListener('change', function (event) {
            var files = event.target.files;
            if (files && files.length > 0) {
              var formData = new FormData();
              Array.from(files).forEach(function (file) {
                formData.append('upload', file);
              });
              formData.append('editor_id', _this3.state.editor_id);
              _this3._uploadFiles(formData);
            } else {
              console.log('No files selected');
            }
          });
        });

        // Set the sidebar view template
        this.sidebarView.setTemplate({
          tag: 'div',
          attributes: {
            "class": 'ckbox-navbar upldFls__navbar'
          },
          children: [imageButton, documentsButton, {
            tag: 'div',
            attributes: {
              "class": 'upldFls__search'
            },
            children: [searchInput, searchButton]
          }, imageUploadButton]
        });
      }
    }

    // Creates the main content panel
  }, {
    key: "_createMainPanel",
    value: function _createMainPanel(locale) {
      var mainPanelView = new View(locale);
      this.itemsCollection = new ViewCollection(locale);
      this._createPagination(locale);

      // Populate the collection with initial state
      this._updateItemsCollection();
      mainPanelView.setTemplate({
        tag: 'div',
        attributes: {
          "class": 'ckbox-view upldFls__view'
        },
        children: [{
          tag: 'div',
          attributes: {
            "class": 'upldFls__viewItems'
          },
          children: this.itemsCollection
        }, this.paginationView]
      });
      return mainPanelView;
    }
  }, {
    key: "_updateItemsCollection",
    value: function _updateItemsCollection() {
      var _this4 = this;
      this.itemsCollection.clear(); // Clear existing items in the collection

      if (this.isLoading) {
        var loadingView = new View(this.editor.locale);
        loadingView.setTemplate({
          tag: 'div',
          attributes: {
            "class": 'upldFls__loading'
          },
          children: [{
            tag: 'p',
            attributes: {
              "class": ''
            },
            children: ['Wird geladen...']
          }]
        });
        this.itemsCollection.add(loadingView);
      } else {
        if (this.state.items.length === 0) {
          var nothingFoundView = new View(this.editor.locale);
          nothingFoundView.setTemplate({
            tag: 'div',
            attributes: {
              "class": 'upldFls__loading'
            },
            children: [{
              tag: 'p',
              attributes: {
                "class": ''
              },
              children: ['Nothing found.']
            }]
          });
          this.itemsCollection.add(nothingFoundView);
        } else {
          this.state.items.forEach(function (item) {
            var itemView = new ChildView(_this4.editor.locale, item, _this4.state.chosen.id);
            _this4.listenTo(itemView, 'item:select', function (evt, selectedItem) {
              if (Object.keys(_this4.state.chosen).length === 0 || _this4.state.chosen.id !== selectedItem.id) {
                _this4.state.chosen = selectedItem;
              } else {
                _this4.state.chosen = {};
              }
              _this4._updateItemsCollection();
              _this4._updateSidebarView();
            });
            _this4.itemsCollection.add(itemView);
          });
        }
      }
    }

    // Creates the pagination view
  }, {
    key: "_createPagination",
    value: function _createPagination(locale) {
      this.paginationView = new View(locale);
      this.linksCollection = new ViewCollection(locale);
      this.paginationView.setTemplate({
        tag: 'div',
        attributes: {
          "class": 'upldFls__pagination'
        },
        children: this.linksCollection
      });

      // Dynamically bind pagination buttons
      this._updatePagination();
    }

    // Updates pagination dynamically
  }, {
    key: "_updatePagination",
    value: function _updatePagination() {
      var _this5 = this;
      this.linksCollection.clear();
      if (this.isLoading) {
        return;
      }
      var _loop = function _loop(i) {
        var buttonView = new ButtonView(_this5.editor.locale);
        buttonView.set({
          label: i,
          withText: true,
          "class": "upldFls__paginationLink ".concat(_this5.state.page === i ? 'active' : '')
        });
        _this5.listenTo(buttonView, 'execute', function () {
          _this5.state.page = i;
          _this5._fetchFiles({
            type: _this5.state.type,
            search: _this5.state.search,
            page: _this5.state.page
          });
        });
        _this5.linksCollection.add(buttonView);
      };
      for (var i = 1; i <= this.state.total_pages; i++) {
        _loop(i);
      }
    }

    // Handle choosing type of files
  }, {
    key: "_handleTypeClick",
    value: function _handleTypeClick(type) {
      this.state.type = type;
      this._fetchFiles({
        type: this.state.type,
        page: 1,
        search: ''
      });
    }

    // Handle search keyword submission
  }, {
    key: "_handleSearchSubmit",
    value: function _handleSearchSubmit() {
      this._fetchFiles({
        type: this.state.type,
        page: 1,
        search: this.state.search
      });
    }

    // Fetches files from the API
  }, {
    key: "_fetchFiles",
    value: function _fetchFiles(params) {
      var _this6 = this;
      this.isLoading = true;
      this._updateItemsCollection();
      this._updatePagination();
      fetch(this.apiGet, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-TOKEN': this.csrf_token
        },
        body: JSON.stringify(_objectSpread(_objectSpread({}, params), {}, {
          editor_id: this.state.editor_id
        }))
      }).then(function (response) {
        return response.json();
      }).then(function (data) {
        _this6.state.total_pages = data.total_pages;
        _this6.state.items = data.items;
      })["catch"](function (error) {
        console.error('Error fetching files:', error.message);
      })["finally"](function () {
        _this6.isLoading = false;
        _this6._updateItemsCollection();
        _this6._updatePagination();
      });
    }
  }, {
    key: "_uploadFiles",
    value: function _uploadFiles(data) {
      var _this7 = this;
      fetch(this.apiUpload[this.state.type], {
        method: 'POST',
        headers: {
          'X-CSRF-TOKEN': this.csrf_token
        },
        body: data
      }).then(function (response) {
        return response.json();
      }).then(function (resp) {
        _this7.state.items = [resp].concat(_toConsumableArray(_this7.state.items));
      })["catch"](function (error) {
        console.error('Error uploading files:', error.message);
      })["finally"](function () {
        _this7._updateItemsCollection();
        _this7._updatePagination();
      });
    }
  }, {
    key: "_editFile",
    value: function _editFile() {
      var _this8 = this;
      var formData = new FormData();
      formData.append('picture[title]', this.state.chosen.title);
      formData.append('picture[description]', this.state.chosen.description);
      formData.append('picture[alt_text]', this.state.chosen.alt_text);
      formData.append('editor_id', this.state.editor_id);
      fetch(this.apiPut(this.state.chosen.id), {
        method: 'PATCH',
        headers: {
          'X-CSRF-TOKEN': this.csrf_token
        },
        body: formData
      }).then(function (response) {
        return response.json();
      }).then(function (data) {
        if (data.id) {
          _this8.state.items = _this8.state.items.map(function (o) {
            return o.id === data.id ? data : o;
          });
          var chosenArr = _this8.state.items.filter(function (o) {
            return o.id === data.id;
          });
          if (chosenArr.length) {
            _this8.state.chosen = chosenArr[0];
          }
        }
      })["catch"](function (error) {
        console.error('Error updating file:', error.message);
      })["finally"](function () {
        _this8._updateSidebarView();
      });
    }
  }, {
    key: "_deleteFile",
    value: function _deleteFile() {
      var _this9 = this;
      var chosenId = this.state.chosen.id;
      fetch(this.apiPut(chosenId), {
        method: 'DELETE',
        headers: {
          'X-CSRF-TOKEN': this.csrf_token
        }
      }).then(function (response) {
        return response.json();
      }).then(function (data) {
        if (data.status && data.status === 'no_content') {
          _this9.state.items = _this9.state.items.filter(function (o) {
            return o.id !== chosenId;
          });
          _this9.state.chosen = {};
        }
      })["catch"](function (error) {
        console.error('Error fetching files:', error.message);
      })["finally"](function () {
        _this9._updateItemsCollection();
        _this9._updatePagination();
        _this9._updateSidebarView();
      });
    }
  }], [{
    key: "pluginName",
    get: function get() {
      return 'UploadFilesPlugin';
    }
  }]);
}(Plugin); // Custom ChildView class for displaying each item
var ChildView = /*#__PURE__*/function (_View) {
  function ChildView(locale, item) {
    var _this10;
    var chosenId = arguments.length > 2 && arguments[2] !== undefined ? arguments[2] : 0;
    _classCallCheck(this, ChildView);
    _this10 = _callSuper(this, ChildView, [locale]);
    _this10.item = item;

    // Set template based on item type
    if (item.data_content_type.startsWith('image/')) {
      _this10.setTemplate({
        tag: 'div',
        attributes: {
          "class": "upldFls__item ".concat(chosenId === item.id ? 'active' : '')
        },
        children: [{
          tag: 'div',
          attributes: {
            "class": 'upldFls__itemThumb'
          },
          children: [{
            tag: 'img',
            attributes: {
              src: item.thumb_url,
              alt: item.alt_text || 'Image',
              style: {
                width: '100%',
                height: 'auto'
              }
            }
          }]
        }, {
          tag: 'p',
          attributes: {
            "class": 'upldFls__item-title'
          },
          children: [item.title || item.data_file_name]
        }]
      });
    } else {
      _this10.setTemplate({
        tag: 'div',
        attributes: {
          "class": "upldFls__item ".concat(chosenId === item.id ? 'active' : '')
        },
        children: [{
          tag: 'div',
          attributes: {
            "class": "upldFls__itemThumb file"
          },
          children: [{
            tag: 'span',
            attributes: {
              "class": 'upldFls__itemIconType'
            },
            children: ["\uD83D\uDCC4".concat(item.data_content_type)]
          }]
        }, {
          tag: 'p',
          attributes: {
            "class": 'upldFls__item-title'
          },
          children: [item.title || item.data_file_name]
        }]
      });
    }
    _this10.on('render', function () {
      _this10.element.addEventListener('click', function () {
        _this10.fire('item:select', item);
      });
    });
    return _this10;
  }
  _inherits(ChildView, _View);
  return _createClass(ChildView);
}(View);
window.UploadFilesPlugin = UploadFilesPlugin;
