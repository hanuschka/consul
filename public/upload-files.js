var { ClassicEditor, Plugin, ButtonView, icons, Dialog, View, InputTextView, ViewCollection } = CKEDITOR;

class UploadFilesPlugin extends Plugin {
    constructor(editor) {
        super(editor);

        // Default state
        this.url = ''; //https://demo.demokratie.today
        this.apiGet = `${this.url}/ckeditor/assets`;
        this.apiUpload = {
            picture:  `${this.url}/ckeditor/pictures`,
            document: `${this.url}/ckeditor/documents`
        }
        this.apiPut = (id) => `${this.url}/ckeditor/pictures/${id}`;
        this.fileAccept = {
            picture: 'image/*',
            document: ''
        }
        this.csrf_token = document.querySelector('meta[name="csrf-token"]')
            ? document.querySelector('meta[name="csrf-token"]').content
            : 'test';
        this.state = {
            editor_id:   editor.sourceElement.id,
            type:        'picture',
            page:        1,
            search:      '',
            total_pages: 0,
            items:       [],
            chosen:      {},
            isLoading:   false
        };
    }

    // Make sure the "Dialog" plugin is loaded.
    get requires() {
        return [Dialog];
    }

    static get pluginName() {
        return 'UploadFilesPlugin'
    }

    init() {
        const editor = this.editor;

        // Add the "upload files" button to the toolbar.
        editor.ui.componentFactory.add('uploadFiles', (locale) => {
            const buttonView = new ButtonView(locale);

            buttonView.set({
                label:   'Dateien hochladen',
                icon:    icons.browseFiles,
                tooltip: true
            });

            buttonView.on('execute', () => {
                const dialog = this.editor.plugins.get('Dialog');

                if (buttonView.isOn) {
                    dialog.hide();
                    buttonView.isOn = false;
                    return;
                }

                buttonView.isOn = true;

                this._createDialogContent(locale);

                // Show the dialog with the generated content
                dialog.show({
                    title:         'CkEditor-Dateien',
                    content:       this.dialogView,
                    actionButtons: [
                        {
                            label:     'Wählen',
                            class:     'ck-button-action',
                            withText:  true,
                            onExecute: () => {
                                if (this.state.chosen.url) {
                                    const editor = this.editor;
                                    const chosenItem = this.state.chosen;

                                    if (chosenItem.data_content_type.startsWith('image/')) {
                                        editor.model.change(writer => {
                                            const selection = editor.model.document.selection;
                                            let insertPosition = selection.getFirstPosition();

                                            const canInsertImageBlock = editor.model.schema.checkChild(insertPosition.parent, 'imageBlock');
                                            const canInsertImageInline = editor.model.schema.checkChild(insertPosition.parent, 'imageInline');

                                            if (canInsertImageBlock) {
                                                const imageBlockElement = writer.createElement('imageBlock', {
                                                    src: this.state.chosen.url,
                                                    alt: this.state.chosen.alt_text || 'Default alt text',
                                                });

                                                editor.model.insertContent(imageBlockElement, insertPosition);
                                                writer.setSelection(imageBlockElement, 'on');

                                            } else if (canInsertImageInline) {
                                                const imageInlineElement = writer.createElement('imageInline', {
                                                    src: this.state.chosen.url,
                                                    alt: this.state.chosen.alt_text || this.state.chosen.data_file_name,
                                                });

                                                editor.model.insertContent(imageInlineElement, insertPosition);
                                                writer.setSelection(imageInlineElement, 'on');
                                            } else {
                                                const root = editor.model.document.getRoot();
                                                const fallbackPosition = writer.createPositionAt(root, 'end');

                                                const fallbackImageBlockElement = writer.createElement('imageBlock', {
                                                    src: this.state.chosen.url,
                                                    alt: this.state.chosen.alt_text || this.state.chosen.data_file_name,
                                                });

                                                editor.model.insertContent(fallbackImageBlockElement, fallbackPosition);
                                                writer.setSelection(fallbackImageBlockElement, 'on');
                                            }
                                        });
                                    } else {
                                        editor.model.change(writer => {
                                            const linkText = chosenItem.title || chosenItem.data_file_name || 'File';
                                            const linkUrl = chosenItem.url;

                                            const linkRange = writer.createText(linkText, {
                                                linkHref: linkUrl,
                                            });
                                            editor.model.insertContent(linkRange, editor.model.document.selection);
                                        });
                                    }
                                }

                                dialog.hide()
                            }
                        }
                    ],
                    onHide: () => {
                        this.state = {
                            type:        'picture',
                            page:        1,
                            search:      '',
                            total_pages: 0,
                            items:       [],
                            chosen:      {},
                            isLoading:   false
                        }
                        buttonView.isOn = false;
                    }
                });

                // Fetch the initial files when the dialog opens
                this._fetchFiles({
                    type:   this.state.type,
                    page:   this.state.page,
                    search: this.state.search
                });
            });

            return buttonView;
        });
    }

    // Creates the dialog content view
    _createDialogContent(locale) {
        this.dialogView = new View(locale);

        this._createSidebar();
        const mainPanel = this._createMainPanel(locale);

        this.dialogView.setTemplate({
            tag:        'div',
            attributes: {
                style: {
                    display:       'flex',
                    flexDirection: 'column',
                    whiteSpace:    'initial',
                    width:         '90vw',
                    maxWidth:      '800px'
                },
                class: 'upldFls__wrapper ck-reset_all-excluded'
            },
            children:   [
                {
                    tag:        'div',
                    attributes: {
                        class: 'upldFls__inner'
                    },
                    children:   [this.sidebarView, mainPanel]
                }
            ]
        });
    }

    _updateSidebarView() {
        this._createSidebar();

        if (this.sidebarView && this.sidebarView.isRendered === false) {
            this.sidebarView.render();
        }

        const sidebarContainer = this.dialogView.element.querySelector('.upldFls__inner > .ckbox-navbar');
        if (sidebarContainer) {
            sidebarContainer.replaceWith(this.sidebarView.element);
        }
    }

    _createSidebar() {
        this.sidebarView = new View(this.editor.locale);

        if (this.state.chosen && Object.keys(this.state.chosen).length > 0) {
            // Sidebar for the chosen item
            const chosenItem = this.state.chosen;

            const titleLabel = new View(this.editor.locale);
            titleLabel.setTemplate({
                tag: 'label',
                attributes: {
                    class: 'upldFls__details'
                },
                children: ['Title']
            });

            const titleInput = new InputTextView(this.editor.locale);
            titleInput.set({
                value: chosenItem.title,
                placeholder: 'Title',
                multiline: true
            });
            titleInput.bind('value').to(() => {
                return chosenItem.title;
            });
            titleInput.on('input', (event) => {
                this.state.chosen.title = event.source.element.value;
            });

            const descriptionLabel = new View(this.editor.locale);
            descriptionLabel.setTemplate({
                tag: 'label',
                attributes: {
                    class: 'upldFls__details'
                },
                children: ['Description']
            });

            const descriptionInput = new InputTextView(this.editor.locale);
            descriptionInput.set({
                value: chosenItem.description,
                placeholder: 'Beschreibung',
                multiline: true
            });

            descriptionInput.bind('value').to(() => {
                return chosenItem.description;
            });

            descriptionInput.on('input', (event) => {
                this.state.chosen.description = event.source.element.value;
            });

            const altTextLabel = new View(this.editor.locale);
            altTextLabel.setTemplate({
                tag: 'label',
                attributes: {
                    class: 'upldFls__details'
                },
                children: ['Alt Text']
            });

            const altTextInput = new InputTextView(this.editor.locale);
            altTextInput.set({
                value: chosenItem.alt_text,
                placeholder: 'Alt Text',
                multiline: true
            });
            altTextInput.bind('value').to(() => {
                return chosenItem.alt_text;
            });
            altTextInput.on('input', (event) => {
                this.state.chosen.alt_text = event.source.element.value;
            });

            const editButton = new ButtonView(this.editor.locale);
            editButton.set({
                label: 'Aktualisieren',
                withText: true,
                class: 'upldFls__btnEdit'
            });
            this.listenTo(editButton, 'execute', () => {
                this._editFile();
            });

            //*********

            // Display chosen item details
            const fileName = new View(this.editor.locale);
            fileName.setTemplate({
                tag: 'p',
                attributes: {
                    class: 'upldFls__details'
                },
                children: [`Name: ${chosenItem.data_file_name}`]
            });

            const uploadDate = new View(this.editor.locale);
            uploadDate.setTemplate({
                tag: 'p',
                attributes: {
                    class: 'upldFls__details'
                },
                children: [`Upload Date: ${chosenItem.created_at}`]
            });

            const fileSize = new View(this.editor.locale);
            fileSize.setTemplate({
                tag: 'p',
                attributes: {
                    class: 'upldFls__details'
                },
                children: [`File Size: ${parseInt(chosenItem.data_file_size/1024)}kb`]
            });

            const fileDimensions = new View(this.editor.locale);
            if (chosenItem.width && chosenItem.height) {
                fileDimensions.setTemplate({
                    tag: 'p',
                    attributes: {
                        class: 'upldFls__details'
                    },
                    children: [`Dimensions: ${chosenItem.width} x ${chosenItem.height}`]
                });
            }

            // *******

            const deleteButton = new ButtonView(this.editor.locale);
            deleteButton.set({
                label: 'Löschen',
                withText: true,
                class: 'upldFls__btnDelete'
            });
            this.listenTo(deleteButton, 'execute', () => {
                this._deleteFile();
            });

            this.sidebarView.setTemplate({
                tag: 'div',
                attributes: {
                    class: 'ckbox-navbar upldFls__navbar'
                },
                children: [
                    {
                        tag: 'div',
                        attributes: {
                            class: 'upldFls__editForm'
                        },
                        children: [titleLabel, titleInput, descriptionLabel, descriptionInput, altTextLabel, altTextInput, editButton]
                    },
                    {
                        tag: 'div',
                        attributes: {
                            class: 'upldFls__metaData'
                        },
                        children: [
                            fileName,
                            uploadDate,
                            fileSize,
                            ...(chosenItem.width && chosenItem.height ? [fileDimensions] : [])
                        ]
                    },
                    {
                        tag: 'div',
                        attributes: {
                            class: 'upldFls__editForm'
                        },
                        children: [deleteButton]
                    }
                ]
            });
        } else {
            const imageButton = new ButtonView(this.editor.locale);
            imageButton.set({
                label: 'Bilder',
                tooltip: true,
                withText: true,
                class:    `upldFls__btn ${this.state.type === 'picture' ? 'active' : ''}`
            });

            this.listenTo(imageButton, 'execute', () => {
                this._handleTypeClick('picture');
                updateButtonClasses();
            });

            // Create the documents button
            const documentsButton = new ButtonView(this.editor.locale);
            documentsButton.set({
                label: 'Dokumente',
                tooltip: true,
                withText: true,
                class:    `upldFls__btn ${this.state.type === 'document' ? 'active' : ''}`
            });

            this.listenTo(documentsButton, 'execute', () => {
                this._handleTypeClick('document');
                updateButtonClasses();
            });

            // Update button classes dynamically based on state
            const updateButtonClasses = () => {
                if (this.state.type === 'picture' && imageButton.element) {
                    imageButton.element.classList.add('active');
                    documentsButton.element.classList.remove('active');
                } else if (this.state.type === 'document' && documentsButton.element) {
                    documentsButton.element.classList.add('active');
                    imageButton.element.classList.remove('active');
                }
            };

            // Call updateButtonClasses initially and whenever the type changes
            updateButtonClasses();

            //this.listenTo(this, 'change:type', updateButtonClasses);

            // Create the search input
            const searchInput = new InputTextView(this.editor.locale);
            searchInput.set({
                value: this.state.search,
                placeholder: 'Suchen...'
            });

            searchInput.bind('value').to(() => {
                return this.state.search;
            });

            searchInput.on('input', (event) => {
                this.state.search = event.source.element.value;
            });

            // Create the search button
            const searchButton = new ButtonView(this.editor.locale);
            searchButton.set({
                label: 'Suchen',
                icon: icons.search,
                tooltip: true,
                withText: true,
                class: 'upldFls__searchBtn'
            });

            this.listenTo(searchButton, 'execute', () => {
                this._handleSearchSubmit();
            });

            // Create the upload button
            const imageUploadButton = new ButtonView(this.editor.locale);
            imageUploadButton.set({
                label: 'Upload files',
                icon: icons.importExport,
                tooltip: true,
                withText: true,
                class: 'upldFls__btnUpload'
            });

            this.listenTo(imageUploadButton, 'execute', () => {
                const fileInput = document.createElement('input');
                fileInput.type = 'file';
                fileInput.accept = this.fileAccept[this.state.type];

                fileInput.click();

                fileInput.addEventListener('change', (event) => {
                    const files = event.target.files;

                    if (files && files.length > 0) {
                        const formData = new FormData();
                        Array.from(files).forEach(file => {
                            formData.append('upload', file);
                        });
                        formData.append('editor_id', this.state.editor_id);

                        this._uploadFiles(formData);
                    } else {
                        console.log('No files selected');
                    }
                });
            });

            // Set the sidebar view template
            this.sidebarView.setTemplate({
                tag: 'div',
                attributes: {
                    class: 'ckbox-navbar upldFls__navbar'
                },
                children: [
                    imageButton,
                    documentsButton,
                    {
                        tag: 'div',
                        attributes: {
                            class: 'upldFls__search'
                        },
                        children: [searchInput, searchButton]
                    },
                    imageUploadButton
                ]
            });
        }
    }

    // Creates the main content panel
    _createMainPanel(locale) {
        const mainPanelView = new View(locale);

        this.itemsCollection = new ViewCollection(locale);
        this._createPagination(locale);

        // Populate the collection with initial state
        this._updateItemsCollection();

        mainPanelView.setTemplate({
            tag:        'div',
            attributes: {
                class: 'ckbox-view upldFls__view'
            },
            children:   [
                {
                    tag:        'div',
                    attributes: {
                        class: 'upldFls__viewItems'
                    },
                    children:   this.itemsCollection
                },
                this.paginationView
            ]
        });

        return mainPanelView;
    }

    _updateItemsCollection() {
        this.itemsCollection.clear(); // Clear existing items in the collection

        if (this.isLoading) {
            const loadingView = new View(this.editor.locale);
            loadingView.setTemplate({
                tag:        'div',
                attributes: {
                    class: 'upldFls__loading'
                },
                children:   [
                    {
                        tag:        'p',
                        attributes: {
                            class: ''
                        },
                        children:   ['Wird geladen...']
                    }
                ]
            });
            this.itemsCollection.add(loadingView);
        } else {
            if (this.state.items.length === 0) {
                const nothingFoundView = new View(this.editor.locale);
                nothingFoundView.setTemplate({
                    tag:        'div',
                    attributes: {
                        class: 'upldFls__loading'
                    },
                    children:   [
                        {
                            tag:        'p',
                            attributes: {
                                class: ''
                            },
                            children:   ['Nothing found.']
                        }
                    ]
                });
                this.itemsCollection.add(nothingFoundView);
            } else {
                this.state.items.forEach((item) => {
                    const itemView = new ChildView(this.editor.locale, item, this.state.chosen.id);

                    this.listenTo(itemView, 'item:select', (evt, selectedItem) => {
                        if (
                            Object.keys(this.state.chosen).length === 0 ||
                            this.state.chosen.id !== selectedItem.id
                        ) {
                            this.state.chosen = selectedItem;
                        } else {
                            this.state.chosen = {};
                        }

                        this._updateItemsCollection();
                        this._updateSidebarView();
                    });

                    this.itemsCollection.add(itemView);
                });
            }
        }
    }

    // Creates the pagination view
    _createPagination(locale) {
        this.paginationView = new View(locale);
        this.linksCollection = new ViewCollection(locale);

        this.paginationView.setTemplate({
            tag:        'div',
            attributes: {
                class: 'upldFls__pagination'
            },
            children:   this.linksCollection
        });

        // Dynamically bind pagination buttons
        this._updatePagination();
    }

    // Updates pagination dynamically
    _updatePagination() {
        this.linksCollection.clear();
        if (this.isLoading) {
            return;
        }

        for (let i = 1; i <= this.state.total_pages; i++) {
            const buttonView = new ButtonView(this.editor.locale);

            buttonView.set({
                label:    i,
                withText: true,
                class:    `upldFls__paginationLink ${this.state.page === i ? 'active' : ''}`
            });

            this.listenTo(buttonView, 'execute', () => {
                this.state.page = i;
                this._fetchFiles({
                    type:   this.state.type,
                    search: this.state.search,
                    page:   this.state.page
                });
            });

            this.linksCollection.add(buttonView);
        }
    }

    // Handle choosing type of files
    _handleTypeClick(type) {
        this.state.type = type;

        this._fetchFiles({
            type:   this.state.type,
            page:   1,
            search: ''
        });
    }

    // Handle search keyword submission
    _handleSearchSubmit() {
        this._fetchFiles({
            type:   this.state.type,
            page:   1,
            search: this.state.search
        });
    }

    // Fetches files from the API
    _fetchFiles(params) {
        this.isLoading = true;
        this._updateItemsCollection();
        this._updatePagination();

        fetch(this.apiGet, {
            method:  'POST',
            headers: {
                'Content-Type': 'application/json',
                'X-CSRF-TOKEN': this.csrf_token
            },
            body:    JSON.stringify({
                ...params,
                editor_id: this.state.editor_id
            })
        })
            .then((response) => response.json())
            .then((data) => {
                this.state.total_pages = data.total_pages;
                this.state.items = data.items;
            })
            .catch((error) => {
                console.error('Error fetching files:', error.message);
            })
            .finally(() => {
                this.isLoading = false;
                this._updateItemsCollection();
                this._updatePagination();
            });
    }

    _uploadFiles(data) {
        fetch(this.apiUpload[this.state.type], {
            method:  'POST',
            headers: {
                'X-CSRF-TOKEN': this.csrf_token
            },
            body: data
        })
            .then((response) => response.json())
            .then((resp) => {
                this.state.items = [resp, ...this.state.items];
            })
            .catch((error) => {
                console.error('Error uploading files:', error.message);
            })
            .finally(() => {
                this._updateItemsCollection();
                this._updatePagination();
            });
    }

    _editFile() {
        const formData = new FormData();
        formData.append('picture[title]', this.state.chosen.title);
        formData.append('picture[description]', this.state.chosen.description);
        formData.append('picture[alt_text]', this.state.chosen.alt_text);
        formData.append('editor_id', this.state.editor_id);

        fetch(this.apiPut(this.state.chosen.id), {
            method:  'PATCH',
            headers: {
                'X-CSRF-TOKEN': this.csrf_token
            },
            body: formData
        })
            .then((response) => response.json())
            .then((data) => {
                if (data.id) {
                    this.state.items = this.state.items.map(o => o.id === data.id ? data : o);
                    const chosenArr = this.state.items.filter(o => o.id === data.id);
                    if (chosenArr.length) {
                        this.state.chosen = chosenArr[0];
                    }
                }

            })
            .catch((error) => {
                console.error('Error updating file:', error.message);
            })
            .finally(() => {
                this._updateSidebarView();
            });
    }

    _deleteFile() {
        const chosenId = this.state.chosen.id;
        fetch(this.apiPut(chosenId), {
            method:  'DELETE',
            headers: {
                'X-CSRF-TOKEN': this.csrf_token
            }
        })
            .then((response) => response.json())
            .then((data) => {
                if (data.status && data.status === 'no_content') {
                    this.state.items = this.state.items.filter(o => o.id !== chosenId);
                    this.state.chosen = {};
                }
            })
            .catch((error) => {
                console.error('Error fetching files:', error.message);
            })
            .finally(() => {
                this._updateItemsCollection();
                this._updatePagination();
                this._updateSidebarView();
            });
    }
}

// Custom ChildView class for displaying each item
class ChildView extends View {
    constructor(locale, item, chosenId = 0) {
        super(locale);

        this.item = item;

        // Set template based on item type
        if (item.data_content_type.startsWith('image/')) {
            this.setTemplate({
                tag:        'div',
                attributes: {
                    class: `upldFls__item ${chosenId === item.id ? 'active' : ''}`
                },
                children:   [
                    {
                        tag:        'div',
                        attributes: {
                            class: 'upldFls__itemThumb'
                        },
                        children:   [{
                            tag:        'img',
                            attributes: {
                                src:   item.thumb_url,
                                alt:   item.alt_text || 'Image',
                                style: { width: '100%', height: 'auto' }
                            }
                        }]
                    },
                    {
                        tag:        'p',
                        attributes: {
                            class: 'upldFls__item-title'
                        },
                        children:   [item.title || item.data_file_name]
                    }
                ]
            });
        } else {
            this.setTemplate({
                tag:        'div',
                attributes: {
                    class: `upldFls__item ${chosenId === item.id ? 'active' : ''}`
                },
                children:   [
                    {
                        tag:        'div',
                        attributes: {
                            class: `upldFls__itemThumb file`
                        },
                        children:   [{
                            tag:        'span',
                            attributes: {
                                class: 'upldFls__itemIconType'
                            },
                            children:   [`📄${item.data_content_type}`]
                        }]
                    },
                    {
                        tag:        'p',
                        attributes: {
                            class: 'upldFls__item-title'
                        },
                        children:   [item.title || item.data_file_name]
                    }
                ]
            });
        }

        this.on('render', () => {
            this.element.addEventListener('click', () => {
                this.fire('item:select', item);
            });
        });
    }
}

window.UploadFilesPlugin = UploadFilesPlugin;
