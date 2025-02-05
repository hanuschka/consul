"use strict";

function _typeof(o) { "@babel/helpers - typeof"; return _typeof = "function" == typeof Symbol && "symbol" == typeof Symbol.iterator ? function (o) { return typeof o; } : function (o) { return o && "function" == typeof Symbol && o.constructor === Symbol && o !== Symbol.prototype ? "symbol" : typeof o; }, _typeof(o); }
function _toConsumableArray(r) { return _arrayWithoutHoles(r) || _iterableToArray(r) || _unsupportedIterableToArray(r) || _nonIterableSpread(); }
function _nonIterableSpread() { throw new TypeError("Invalid attempt to spread non-iterable instance.\nIn order to be iterable, non-array objects must have a [Symbol.iterator]() method."); }
function _unsupportedIterableToArray(r, a) { if (r) { if ("string" == typeof r) return _arrayLikeToArray(r, a); var t = {}.toString.call(r).slice(8, -1); return "Object" === t && r.constructor && (t = r.constructor.name), "Map" === t || "Set" === t ? Array.from(r) : "Arguments" === t || /^(?:Ui|I)nt(?:8|16|32)(?:Clamped)?Array$/.test(t) ? _arrayLikeToArray(r, a) : void 0; } }
function _iterableToArray(r) { if ("undefined" != typeof Symbol && null != r[Symbol.iterator] || null != r["@@iterator"]) return Array.from(r); }
function _arrayWithoutHoles(r) { if (Array.isArray(r)) return _arrayLikeToArray(r); }
function _arrayLikeToArray(r, a) { (null == a || a > r.length) && (a = r.length); for (var e = 0, n = Array(a); e < a; e++) n[e] = r[e]; return n; }
function ownKeys(e, r) { var t = Object.keys(e); if (Object.getOwnPropertySymbols) { var o = Object.getOwnPropertySymbols(e); r && (o = o.filter(function (r) { return Object.getOwnPropertyDescriptor(e, r).enumerable; })), t.push.apply(t, o); } return t; }
function _objectSpread(e) { for (var r = 1; r < arguments.length; r++) { var t = null != arguments[r] ? arguments[r] : {}; r % 2 ? ownKeys(Object(t), !0).forEach(function (r) { _defineProperty(e, r, t[r]); }) : Object.getOwnPropertyDescriptors ? Object.defineProperties(e, Object.getOwnPropertyDescriptors(t)) : ownKeys(Object(t)).forEach(function (r) { Object.defineProperty(e, r, Object.getOwnPropertyDescriptor(t, r)); }); } return e; }
function _defineProperty(e, r, t) { return (r = _toPropertyKey(r)) in e ? Object.defineProperty(e, r, { value: t, enumerable: !0, configurable: !0, writable: !0 }) : e[r] = t, e; }
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
    _this.fileAccept = {
      picture: 'image/*',
      document: ''
    };
    _this.apiPut = function (type, id) {
      return "".concat(_this.apiUpload[type], "/").concat(id);
    };
    _this.csrf_token = document.querySelector('meta[name="csrf-token"]') ? document.querySelector('meta[name="csrf-token"]').content : 'NXRqTpKQhE1fKecDK5REAmaFNsDfmmgnIzoRb5RvC-kJ4eMQ4sYp8uevjZkryQi20oNnyRnWNm9xSSVYx3K9lA';
    _this.state = {
      editor_id: editor.sourceElement.id,
      type: 'picture',
      page: 1,
      search: '',
      total_pages: 0,
      items: [],
      chosen: {},
      isLoading: false,
      enableTargetBlank: false
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
      editor.model.schema.extend('$text', {
        allowAttributes: ['linkHref', 'linkTarget']
      });
      editor.model.schema.register('a', {
        allowChildren: ['imageBlock', 'imageInline', '$text'],
        allowAttributes: ['linkHref', 'linkTarget']
      });
      editor.model.schema.extend('imageBlock', {
        allowIn: ['a']
      });
      editor.model.schema.extend('imageInline', {
        allowIn: ['a']
      });
      editor.model.schema.extend('paragraph', {
        allowChildren: ['a']
      });
      editor.conversion["for"]('downcast').attributeToElement({
        model: 'linkTarget',
        view: function view(targetValue, _ref) {
          var writer = _ref.writer;
          if (targetValue) {
            return writer.createAttributeElement('a', {
              target: targetValue
            }, {
              priority: 5
            });
          }
        }
      });
      editor.conversion["for"]('upcast').attributeToAttribute({
        view: {
          name: 'a',
          key: 'target'
        },
        model: 'linkTarget'
      });

      // Add the "upload files" button to the toolbar.
      editor.ui.componentFactory.add('uploadFiles', function (locale) {
        var buttonView = new ButtonView(locale);
        buttonView.set({
          label: 'Dateien hochladen',
          icon: icons.browseFiles,
          tooltip: true
        });
        buttonView.on('execute', function () {
          _this2.dialog = _this2.editor.plugins.get('Dialog');
          if (buttonView.isOn) {
            _this2.dialog.hide();
            buttonView.isOn = false;
            return;
          }
          buttonView.isOn = true;
          _this2._createDialogContent(locale);

          // Show the dialog with the generated content
          _this2.dialog.show({
            title: 'Bilder- und Dokumenten Editor',
            content: _this2.dialogView,
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
      this._createEditModal();
      this._createFooter();
      var mainPanel = this._createMainPanel(locale);
      this.dialogView.setTemplate({
        tag: 'div',
        attributes: {
          style: {
            display: 'flex',
            flexDirection: 'column',
            whiteSpace: 'initial',
            width: '90vw',
            maxWidth: '840px',
            height: '70vh'
          },
          "class": 'upldFls__wrapper ck-reset_all-excluded'
        },
        children: [{
          tag: 'div',
          attributes: {
            "class": 'upldFls__inner'
          },
          children: [this.sidebarView, this.editModalView, mainPanel, this.footerView]
        }]
      });
    }
  }, {
    key: "_createFooter",
    value: function _createFooter() {
      var _this3 = this;
      this.footerView = new View(this.editor.locale);
      var mainActionButton = new ButtonView(this.editor.locale);
      mainActionButton.set({
        label: 'Wählen',
        withText: true,
        "class": 'ck-button-action'
      });
      mainActionButton.on('execute', function () {
        if (_this3.state.chosen.url) {
          var editor = _this3.editor;
          var chosenItem = _this3.state.chosen;
          editor.model.change(function (writer) {
            var selection = editor.model.document.selection;
            var selectedElement = selection.getSelectedElement();
            if (chosenItem.data_content_type.startsWith('image/')) {
              var imageAttributes = {
                src: _this3.state.chosen.url,
                alt: _this3.state.chosen.alt_text || 'Default alt text'
              };
              if (selectedElement && ['imageBlock', 'imageInline'].includes(selectedElement.name)) {
                writer.setAttributes(imageAttributes, selectedElement);
                writer.setSelection(selectedElement, 'on');
              } else {
                var insertPosition = selection.getFirstPosition();
                var imageEl = null;
                var canInsertImageBlock = editor.model.schema.checkChild(insertPosition.parent, 'imageBlock');
                var canInsertImageInline = editor.model.schema.checkChild(insertPosition.parent, 'imageInline');
                if (canInsertImageBlock) {
                  imageEl = writer.createElement('imageBlock', imageAttributes);
                } else if (canInsertImageInline) {
                  imageEl = writer.createElement('imageInline', imageAttributes);
                } else {
                  var root = editor.model.document.getRoot();
                  insertPosition = writer.createPositionAt(root, 'end');
                  imageEl = writer.createElement('imageBlock', imageAttributes);
                }
                if (_this3.state.enableTargetBlank) {
                  /*const linkAttributes = {
                      linkHref: chosenItem.url,
                      linkTarget: '_blank'
                  };
                  const anchorElement = writer.createElement('a', linkAttributes);*/
                  editor.model.insertContent(imageEl, insertPosition);
                  writer.setSelection(imageEl, 'on');

                  // throws error :(
                  /*if (editor.model.schema.checkChild(imageEl.parent, 'a')) {
                      const range = writer.createRangeOn(imageEl);
                      writer.wrap(range, anchorElement);
                       writer.setSelection(anchorElement, 'on');
                  } else {
                      console.error('Cannot wrap imageEl with <a> in the current parent:', imageEl.parent);
                  }*/
                } else {
                  editor.model.insertContent(imageEl, insertPosition);
                  writer.setSelection(imageEl, 'on');
                }
              }
            } else {
              var linkAttributes = _objectSpread({
                linkHref: chosenItem.url
              }, _this3.state.enableTargetBlank && {
                linkTarget: '_blank'
              });
              var linkText = chosenItem.title || chosenItem.data_file_name || 'File';
              if (selectedElement && (selectedElement.is('imageBlock') || selectedElement.is('imageInline'))) {
                var linkRange = writer.createText(linkText, linkAttributes);
                writer.insert(linkRange, writer.createRangeOn(selectedElement));
              } else {
                var _linkRange = writer.createText(linkText, linkAttributes);
                editor.model.insertContent(_linkRange, selection);
              }
            }
          });
        }
        _this3.dialog.hide();
      });
      this.footerView.on('render', function () {
        var checkbox = _this3.footerView.element.querySelector('.updateTargetCheckbox');
        if (checkbox) {
          checkbox.addEventListener('change', function (event) {
            _this3.state.enableTargetBlank = event.target.checked;
          });
        }
      });
      this.footerView.setTemplate({
        tag: 'div',
        attributes: {
          "class": 'upldFls__footer'
        },
        children: [{
          tag: 'label',
          attributes: {
            "class": 'upldFls__footerCol'
          },
          children: [{
            tag: 'input',
            attributes: {
              type: 'checkbox',
              "class": 'ck-input ck-checkbox updateTargetCheckbox'
            },
            onExecute: function onExecute(e) {
              console.log('change', e);
            }
          }, 'Dokument soll in neuem Fenster geöffnet werden']
        }, mainActionButton]
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
      var _this4 = this;
      this.sidebarView = new View(this.editor.locale);

      // Images button
      var imageButton = new ButtonView(this.editor.locale);
      imageButton.set({
        label: 'Bilder',
        tooltip: true,
        icon: '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">\n' + '<path d="M21.75 3.75H2.25C1.83516 3.75 1.5 4.08516 1.5 4.5V19.5C1.5 19.9148 1.83516 20.25 2.25 20.25H21.75C22.1648 20.25 22.5 19.9148 22.5 19.5V4.5C22.5 4.08516 22.1648 3.75 21.75 3.75ZM20.8125 18.5625H3.1875V17.6273L6.43359 13.7766L9.95156 17.9484L15.4242 11.4609L20.8125 17.85V18.5625ZM20.8125 15.5203L15.5672 9.3C15.4922 9.21094 15.3562 9.21094 15.2812 9.3L9.95156 15.6188L6.57656 11.618C6.50156 11.5289 6.36562 11.5289 6.29062 11.618L3.1875 15.2977V5.4375H20.8125V15.5203Z" fill="currentColor"/>\n' + '<path opacity="0.1" d="M9.95156 17.9484L6.43359 13.7766L3.1875 17.6273V18.5625H20.8125V17.85L15.4242 11.4609L9.95156 17.9484Z" fill="currentColor"/>\n' + '<path opacity="0.1" d="M3.1875 15.2977L6.29062 11.618C6.36562 11.5289 6.50156 11.5289 6.57656 11.618L9.95156 15.6188L15.2812 9.3C15.3562 9.21094 15.4922 9.21094 15.5672 9.3L20.8125 15.5203V5.4375H3.1875V15.2977ZM7.125 6.5625C7.39585 6.5625 7.66405 6.61585 7.91428 6.7195C8.16452 6.82315 8.39189 6.97507 8.58341 7.16659C8.77493 7.35811 8.92685 7.58548 9.0305 7.83572C9.13415 8.08595 9.1875 8.35415 9.1875 8.625C9.1875 8.89585 9.13415 9.16405 9.0305 9.41428C8.92685 9.66452 8.77493 9.89189 8.58341 10.0834C8.39189 10.2749 8.16452 10.4269 7.91428 10.5305C7.66405 10.6342 7.39585 10.6875 7.125 10.6875C6.57799 10.6875 6.05339 10.4702 5.66659 10.0834C5.2798 9.69661 5.0625 9.17201 5.0625 8.625C5.0625 8.07799 5.2798 7.55339 5.66659 7.16659C6.05339 6.7798 6.57799 6.5625 7.125 6.5625Z" fill="#currentColor"/>\n' + '<path opacity="0.1" d="M6.46875 8.625C6.46875 8.79905 6.53789 8.96597 6.66096 9.08904C6.78403 9.21211 6.95095 9.28125 7.125 9.28125C7.29905 9.28125 7.46597 9.21211 7.58904 9.08904C7.71211 8.96597 7.78125 8.79905 7.78125 8.625C7.78125 8.45095 7.71211 8.28403 7.58904 8.16096C7.46597 8.03789 7.29905 7.96875 7.125 7.96875C6.95095 7.96875 6.78403 8.03789 6.66096 8.16096C6.53789 8.28403 6.46875 8.45095 6.46875 8.625Z" fill="currentColor"/>\n' + '<path d="M7.125 10.6875C7.39585 10.6875 7.66405 10.6342 7.91428 10.5305C8.16452 10.4269 8.39189 10.2749 8.58341 10.0834C8.77493 9.89189 8.92685 9.66452 9.0305 9.41428C9.13415 9.16405 9.1875 8.89585 9.1875 8.625C9.1875 8.35415 9.13415 8.08595 9.0305 7.83572C8.92685 7.58548 8.77493 7.35811 8.58341 7.16659C8.39189 6.97507 8.16452 6.82315 7.91428 6.7195C7.66405 6.61585 7.39585 6.5625 7.125 6.5625C6.57799 6.5625 6.05339 6.7798 5.66659 7.16659C5.2798 7.55339 5.0625 8.07799 5.0625 8.625C5.0625 9.17201 5.2798 9.69661 5.66659 10.0834C6.05339 10.4702 6.57799 10.6875 7.125 10.6875ZM7.125 7.96875C7.48828 7.96875 7.78125 8.26172 7.78125 8.625C7.78125 8.98828 7.48828 9.28125 7.125 9.28125C6.76172 9.28125 6.46875 8.98828 6.46875 8.625C6.46875 8.26172 6.76172 7.96875 7.125 7.96875Z" fill="currentColor"/>\n' + '</svg>',
        "class": "upldFls__btnIcon ".concat(this.state.type === 'picture' ? 'active' : '')
      });
      this.listenTo(imageButton, 'execute', function () {
        _this4._handleTypeClick('picture');
        updateButtonClasses();
      });

      // Documents button
      var documentsButton = new ButtonView(this.editor.locale);
      documentsButton.set({
        label: 'Dokumente',
        tooltip: true,
        icon: '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">\n' + '<path d="M20.0297 6.76641C20.1703 6.90703 20.25 7.09687 20.25 7.29609V21.75C20.25 22.1648 19.9148 22.5 19.5 22.5H4.5C4.08516 22.5 3.75 22.1648 3.75 21.75V2.25C3.75 1.83516 4.08516 1.5 4.5 1.5H14.4539C14.6531 1.5 14.8453 1.57969 14.9859 1.72031L20.0297 6.76641ZM18.5203 7.64062L14.1094 3.22969V7.64062H18.5203ZM14.8411 14.9358C14.4853 14.9241 14.107 14.9515 13.6774 15.0052C13.1079 14.6538 12.7245 14.1713 12.4521 13.4623L12.4772 13.3596L12.5062 13.2382C12.607 12.8133 12.6612 12.5032 12.6773 12.1905C12.6895 11.9545 12.6764 11.7368 12.6345 11.535C12.5571 11.0993 12.2489 10.8445 11.8605 10.8288C11.4984 10.8141 11.1656 11.0163 11.0805 11.3297C10.942 11.8364 11.0231 12.5032 11.3168 13.6404C10.9427 14.5322 10.4484 15.5777 10.1168 16.1609C9.67406 16.3891 9.3293 16.5968 9.03961 16.827C8.65758 17.1309 8.41898 17.4434 8.35336 17.7715C8.32148 17.9236 8.36953 18.1223 8.47898 18.2852C8.6032 18.4699 8.79023 18.5899 9.01453 18.6073C9.58055 18.6511 10.2762 18.0675 11.0442 16.7496C11.1213 16.7238 11.2029 16.6966 11.3025 16.6629L11.5814 16.5687C11.7579 16.5091 11.8859 16.4665 12.0124 16.4255C12.5609 16.2469 12.9757 16.1341 13.353 16.0699C14.0088 16.421 14.7668 16.6512 15.2773 16.6512C15.6987 16.6512 15.9834 16.4327 16.0863 16.0889C16.1766 15.787 16.1051 15.4369 15.911 15.2433C15.7104 15.0462 15.3415 14.952 14.8411 14.9358ZM9.02883 17.9456V17.9372L9.03187 17.9292C9.06617 17.8406 9.11019 17.756 9.16313 17.677C9.26344 17.5228 9.40148 17.3606 9.57258 17.1879C9.66445 17.0953 9.76008 17.0051 9.87234 16.9038C9.89742 16.8813 10.0577 16.7386 10.0877 16.7105L10.3495 16.4667L10.1592 16.7698C9.87047 17.2301 9.60938 17.5615 9.38578 17.7776C9.30352 17.8573 9.23109 17.9159 9.1725 17.9536C9.15316 17.9665 9.13268 17.9777 9.11133 17.9869C9.10172 17.9909 9.09328 17.9932 9.08484 17.9939C9.07594 17.995 9.06689 17.9938 9.05859 17.9904C9.04977 17.9867 9.04224 17.9805 9.03694 17.9725C9.03165 17.9645 9.02882 17.9552 9.02883 17.9456ZM11.9805 12.8297L11.9276 12.9234L11.8948 12.8208C11.8221 12.5904 11.7687 12.2433 11.7539 11.9302C11.737 11.5739 11.7654 11.3602 11.8779 11.3602C12.0359 11.3602 12.1083 11.6133 12.1139 11.9941C12.1191 12.3288 12.0663 12.6771 11.9803 12.8297H11.9805ZM11.8444 14.1998L11.8802 14.1049L11.9292 14.194C12.2032 14.6918 12.5588 15.1071 12.9497 15.3966L13.0341 15.4589L12.9312 15.48C12.5484 15.5592 12.192 15.6783 11.7045 15.8749C11.7553 15.8543 11.1977 16.0826 11.0566 16.1367L10.9336 16.1838L10.9992 16.0695C11.2887 15.5655 11.5561 14.9604 11.8441 14.1998H11.8444ZM15.5386 15.9872C15.3544 16.0598 14.9578 15.9949 14.2596 15.6968L14.0824 15.6213L14.2746 15.6073C14.8207 15.5667 15.2074 15.5967 15.4329 15.6792C15.529 15.7144 15.593 15.7587 15.6213 15.8093C15.6363 15.8333 15.6413 15.8621 15.6353 15.8897C15.6294 15.9173 15.6129 15.9415 15.5895 15.9572C15.5746 15.9703 15.5573 15.9805 15.5386 15.9872Z" fill="currentColor"/>\n' + '</svg>',
        "class": "upldFls__btnIcon ".concat(this.state.type === 'document' ? 'active' : '')
      });
      this.listenTo(documentsButton, 'execute', function () {
        _this4._handleTypeClick('document');
        updateButtonClasses();
      });

      // Update button classes dynamically based on state
      var updateButtonClasses = function updateButtonClasses() {
        if (_this4.state.type === 'picture' && imageButton.element) {
          imageButton.element.classList.add('active');
          documentsButton.element.classList.remove('active');
        } else if (_this4.state.type === 'document' && documentsButton.element) {
          documentsButton.element.classList.add('active');
          imageButton.element.classList.remove('active');
        }
      };

      // Call updateButtonClasses initially and whenever the type changes
      updateButtonClasses();

      // Create the search input
      var searchInput = new InputTextView(this.editor.locale);
      searchInput.set({
        value: this.state.search,
        placeholder: 'Suchen...'
      });
      searchInput.bind('value').to(function () {
        return _this4.state.search;
      });
      searchInput.on('input', function (event) {
        _this4.state.search = event.source.element.value;
      });
      searchInput.on('render', function () {
        searchInput.element.addEventListener('keydown', function (event) {
          if (event.key === 'Enter') {
            _this4._handleSearchSubmit();
          }
        });
      });
      var cancelKeywordButton = new ButtonView(this.editor.locale);
      cancelKeywordButton.set({
        label: 'Cancel',
        withText: false,
        "class": 'upldFls__iconDelete'
      });
      this.listenTo(cancelKeywordButton, 'execute', function () {
        searchInput.element.value = '';
        _this4.state.search = '';
        _this4._handleSearchSubmit();
      });

      // Edit button
      var editButton = new ButtonView(this.editor.locale);
      editButton.set({
        label: 'Bild editieren',
        withText: true,
        "class": 'upldFls__btnPrimary'
      });
      this.listenTo(editButton, 'execute', function () {
        _this4._updateEditModalView();
      });

      // Create the upload button
      var imageUploadButton = new ButtonView(this.editor.locale);
      imageUploadButton.set({
        label: 'Neues Bild / Dokument hochladen',
        //tooltip:  true,
        withText: true,
        "class": 'upldFls__btnPrimary'
      });
      this.listenTo(imageUploadButton, 'execute', function () {
        var fileInput = document.createElement('input');
        fileInput.type = 'file';
        fileInput.accept = _this4.fileAccept[_this4.state.type];
        fileInput.click();
        fileInput.addEventListener('change', function (event) {
          var files = event.target.files;
          if (files && files.length > 0) {
            var formData = new FormData();
            Array.from(files).forEach(function (file) {
              formData.append('upload', file);
            });
            formData.append('editor_id', _this4.state.editor_id);
            _this4._uploadFiles(formData);
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
        children: [{
          tag: 'div',
          attributes: {
            "class": 'upldFls__filterWrapper'
          },
          children: [{
            tag: 'div',
            attributes: {
              "class": 'upldFls__searchWrapper'
            },
            children: [searchInput, cancelKeywordButton, {
              tag: 'span',
              attributes: {
                "class": 'upldFls__iconSearch'
              },
              children: []
            }]
          }, {
            tag: 'span',
            children: ['Filter:']
          }, imageButton, documentsButton]
        }, {
          tag: 'div',
          attributes: {
            "class": 'upldFls__actionsWrapper'
          },
          children: [this.state.chosen && Object.keys(this.state.chosen).length > 0 ? editButton : '', imageUploadButton]
        }]
      });
    }
  }, {
    key: "_createEditModal",
    value: function _createEditModal() {
      var _this5 = this;
      this.editModalView = new View(this.editor.locale);
      if (this.state.chosen && Object.keys(this.state.chosen).length > 0) {
        // Sidebar for the chosen item
        var chosenItem = this.state.chosen;
        var titleLabel = new View(this.editor.locale);
        titleLabel.setTemplate({
          tag: 'label',
          attributes: {
            "class": 'upldFls__details'
          },
          children: ['Titel']
        });
        var titleInput = new InputTextView(this.editor.locale);
        titleInput.set({
          value: chosenItem.title,
          placeholder: 'Titel',
          multiline: true
        });
        titleInput.bind('value').to(function () {
          return chosenItem.title;
        });
        titleInput.on('input', function (event) {
          _this5.state.chosen.title = event.source.element.value;
        });
        var descriptionLabel = new View(this.editor.locale);
        descriptionLabel.setTemplate({
          tag: 'label',
          attributes: {
            "class": 'upldFls__details'
          },
          children: ['Beschreibung']
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
          _this5.state.chosen.description = event.source.element.value;
        });
        var altTextLabel = new View(this.editor.locale);
        altTextLabel.setTemplate({
          tag: 'label',
          attributes: {
            "class": 'upldFls__details'
          },
          children: ['Alternativer Text']
        });
        var altTextInput = new InputTextView(this.editor.locale);
        altTextInput.set({
          value: chosenItem.alt_text,
          placeholder: 'Alternativer Text (empfohlen)',
          multiline: true
        });
        altTextInput.bind('value').to(function () {
          return chosenItem.alt_text;
        });
        altTextInput.on('input', function (event) {
          _this5.state.chosen.alt_text = event.source.element.value;
        });
        var editButton = new ButtonView(this.editor.locale);
        editButton.set({
          label: 'Aktualisieren',
          withText: true,
          "class": 'upldFls__btnPrimary'
        });
        this.listenTo(editButton, 'execute', function () {
          _this5._editFile();
        });
        var deleteButton = new ButtonView(this.editor.locale);
        deleteButton.set({
          label: 'Löschen',
          withText: true,
          "class": 'upldFls__btnPrimary upldFls__btnDanger'
        });
        this.listenTo(deleteButton, 'execute', function () {
          _this5._deleteFile();
        });
        var closeBtn = new ButtonView(this.editor.locale);
        closeBtn.set({
          label: 'close',
          "class": 'upldFls__btnIcon',
          icon: '<svg width="22" height="22" viewBox="0 0 22 22" fill="none" xmlns="http://www.w3.org/2000/svg">' + '<path fill-rule="evenodd" clip-rule="evenodd" d="M16.1404 4.827C16.1407 4.827 16.1411 4.82735 16.1418 4.82807L17.172 5.85843C17.1727 5.85896 17.1729 5.85932 17.1731 5.85985C17.1732 5.86021 17.1732 5.86057 17.1731 5.86093C17.1731 5.86146 17.1727 5.86182 17.172 5.86253L12.0345 11L17.172 16.1375C17.1727 16.1382 17.1729 16.1386 17.1731 16.1391C17.1732 16.1395 17.1732 16.14 17.1731 16.1404C17.1731 16.1407 17.1727 16.1411 17.172 16.1418L16.1416 17.172C16.1411 17.1727 16.1407 17.1729 16.1404 17.1731C16.14 17.1732 16.1395 17.1732 16.1391 17.1731C16.1386 17.1731 16.1382 17.1727 16.1375 17.172L11 12.0345L5.86253 17.172C5.86182 17.1727 5.86146 17.1729 5.86093 17.1731C5.86052 17.1732 5.86008 17.1732 5.85968 17.1731C5.85932 17.1731 5.85896 17.1727 5.85825 17.172L4.82807 16.1416C4.82735 16.1411 4.82718 16.1407 4.827 16.1404C4.82687 16.14 4.82687 16.1395 4.827 16.1391C4.827 16.1386 4.82735 16.1382 4.82807 16.1375L9.96557 11L4.82807 5.86253C4.82735 5.86182 4.82718 5.86146 4.827 5.86093C4.82687 5.86052 4.82687 5.86008 4.827 5.85968C4.827 5.85932 4.82735 5.85896 4.82807 5.85825L5.85843 4.82807C5.85896 4.82735 5.85932 4.82718 5.85968 4.827C5.86008 4.82687 5.86052 4.82687 5.86093 4.827C5.86146 4.827 5.86182 4.82735 5.86253 4.82807L11 9.96557L16.1375 4.82807C16.1382 4.82735 16.1386 4.82718 16.1391 4.827C16.1395 4.82687 16.14 4.82687 16.1404 4.827Z" fill="black" fill-opacity="0.45"/>' + '</svg>'
        });
        this.listenTo(closeBtn, 'execute', function () {
          _this5.editModalView.element.classList.remove('open');
        });
        this.editModalView.setTemplate({
          tag: 'div',
          attributes: {
            "class": 'upldFls__editModalWrapper open'
          },
          children: [{
            tag: 'div',
            attributes: {
              "class": 'upldFls__editModalOverlay'
            },
            children: []
          }, {
            tag: 'div',
            attributes: {
              "class": 'upldFls__editModal'
            },
            children: [{
              tag: 'div',
              attributes: {
                "class": 'upldFls__editForm'
              },
              children: [{
                tag: 'div',
                attributes: {
                  "class": 'upldFls__editFormHeader'
                },
                children: ['Einstellungen zum Bild / Dokument', closeBtn]
              }, {
                tag: 'div',
                attributes: {
                  "class": 'upldFls__editFormFormField'
                },
                children: [titleLabel, titleInput]
              }, {
                tag: 'div',
                attributes: {
                  "class": 'upldFls__editFormFormField'
                },
                children: [descriptionLabel, descriptionInput]
              }, {
                tag: 'div',
                attributes: {
                  "class": 'upldFls__editFormFormField'
                },
                children: [altTextLabel, altTextInput]
              }, {
                tag: 'div',
                attributes: {
                  "class": 'upldFls__editFormActions'
                },
                children: [deleteButton, editButton]
              }]
            }]
          }]
        });
      } else {
        this.editModalView.setTemplate({
          tag: 'div',
          attributes: {
            "class": 'upldFls__editModalWrapper'
          },
          children: []
        });
      }
    }
  }, {
    key: "_updateEditModalView",
    value: function _updateEditModalView() {
      this._createEditModal();
      if (this.editModalView && this.editModalView.isRendered === false) {
        this.editModalView.render();
      }
      var editModalContainer = this.dialogView.element.querySelector('.upldFls__inner > .upldFls__editModalWrapper');
      if (editModalContainer) {
        editModalContainer.replaceWith(this.editModalView.element);
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
      var _this6 = this;
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
            var itemView = new ChildView(_this6.editor.locale, item, _this6.state.chosen.id);
            _this6.listenTo(itemView, 'item:select', function (evt, selectedItem) {
              if (Object.keys(_this6.state.chosen).length === 0 || _this6.state.chosen.id !== selectedItem.id) {
                _this6.state.chosen = selectedItem;
              } else {
                _this6.state.chosen = {};
              }
              _this6._updateItemsCollection();
              _this6._updateSidebarView();
            });
            _this6.itemsCollection.add(itemView);
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
      var _this7 = this;
      this.linksCollection.clear();
      if (this.isLoading || this.state.total_pages < 2) {
        return;
      }
      var _loop = function _loop(i) {
        var buttonView = new ButtonView(_this7.editor.locale);
        buttonView.set({
          label: i,
          withText: true,
          "class": "upldFls__paginationLink ".concat(_this7.state.page === i ? 'active' : '')
        });
        _this7.listenTo(buttonView, 'execute', function () {
          _this7.state.page = i;
          _this7._fetchFiles({
            type: _this7.state.type,
            search: _this7.state.search,
            page: _this7.state.page
          });
        });
        _this7.linksCollection.add(buttonView);
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
      var _this8 = this;
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
        _this8.state.total_pages = data.total_pages;
        _this8.state.items = data.items;
      })["catch"](function (error) {
        alert(error.message);
      })["finally"](function () {
        _this8.isLoading = false;
        _this8._updateItemsCollection();
        _this8._updatePagination();
      });
    }
  }, {
    key: "_uploadFiles",
    value: function _uploadFiles(data) {
      var _this9 = this;
      fetch(this.apiUpload[this.state.type], {
        method: 'POST',
        headers: {
          'X-CSRF-TOKEN': this.csrf_token
        },
        body: data
      }).then(function (response) {
        return response.json();
      }).then(function (resp) {
        _this9.state.items = [resp].concat(_toConsumableArray(_this9.state.items));
      })["catch"](function (error) {
        alert(error.message);
      })["finally"](function () {
        _this9._updateItemsCollection();
        _this9._updatePagination();
      });
    }
  }, {
    key: "_editFile",
    value: function _editFile() {
      var _this10 = this;
      var formData = new FormData();
      formData.append("".concat(this.state.type, "[title]"), this.state.chosen.title);
      formData.append("".concat(this.state.type, "[description]"), this.state.chosen.description);
      formData.append("".concat(this.state.type, "[alt_text]"), this.state.chosen.alt_text);
      formData.append('editor_id', this.state.editor_id);
      fetch(this.apiPut(this.state.type, this.state.chosen.id), {
        method: 'PATCH',
        headers: {
          'X-CSRF-TOKEN': this.csrf_token
        },
        body: formData
      }).then(function (response) {
        return response.json();
      }).then(function (data) {
        if (data.id) {
          _this10.state.items = _this10.state.items.map(function (o) {
            return o.id === data.id ? data : o;
          });
          var chosenArr = _this10.state.items.filter(function (o) {
            return o.id === data.id;
          });
          if (chosenArr.length) {
            _this10.state.chosen = chosenArr[0];
          }
        }
      })["catch"](function (error) {
        alert(error.message);
      })["finally"](function () {
        _this10._updateSidebarView();
        _this10._updateItemsCollection();
      });
    }
  }, {
    key: "_deleteFile",
    value: function _deleteFile() {
      var _this11 = this;
      var chosenId = this.state.chosen.id;
      fetch(this.apiPut(this.state.type, chosenId), {
        method: 'DELETE',
        headers: {
          'X-CSRF-TOKEN': this.csrf_token
        }
      }).then(function (response) {
        return response.json();
      }).then(function (data) {
        if (data.status && data.status === 'no_content') {
          _this11.state.items = _this11.state.items.filter(function (o) {
            return o.id !== chosenId;
          });
          _this11.state.chosen = {};
        }
      })["catch"](function (error) {
        alert(error.message);
      })["finally"](function () {
        _this11._updateItemsCollection();
        _this11._updatePagination();
        //this._updateSidebarView();
        _this11._updateEditModalView();
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
    var _this12;
    var chosenId = arguments.length > 2 && arguments[2] !== undefined ? arguments[2] : 0;
    _classCallCheck(this, ChildView);
    _this12 = _callSuper(this, ChildView, [locale]);
    _this12.item = item;

    // Set template based on item type
    if (item.data_content_type.startsWith('image/')) {
      _this12.setTemplate({
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
          tag: 'div',
          attributes: {
            "class": 'upldFls__itemMeta'
          },
          children: [{
            tag: 'p',
            attributes: {
              "class": 'upldFls__itemTitle'
            },
            children: [item.title || item.data_file_name]
          }, {
            tag: 'span',
            attributes: {
              "class": 'upldFls__itemAlt'
            },
            children: [item.alt_text || '']
          }]
        }]
      });
    } else {
      _this12.setTemplate({
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
          tag: 'div',
          attributes: {
            "class": 'upldFls__itemMeta'
          },
          children: [{
            tag: 'p',
            attributes: {
              "class": 'upldFls__itemTitle'
            },
            children: [item.title || item.data_file_name]
          }, {
            tag: 'p',
            attributes: {
              "class": 'upldFls__itemAlt'
            },
            children: [item.alt_text || '']
          }]
        }]
      });
    }
    _this12.on('render', function () {
      _this12.element.addEventListener('click', function () {
        _this12.fire('item:select', item);
      });
    });
    return _this12;
  }
  _inherits(ChildView, _View);
  return _createClass(ChildView);
}(View);
window.UploadFilesPlugin = UploadFilesPlugin;
