// Studio content-block editor pack, shared between the legacy frontend
// (projekt studio pages, loaded alongside application.js) and the /adm
// newsletter edit page (loaded after packs/studio_vendor.js, which provides
// jQuery + Foundation there).
//
// NOTE: no jquery/foundation here — on the frontend they come from
// application.js and double-loading jQuery would detach Foundation plugins.
// NOTE: no ckeditor5 here either — on /adm the kern bundle already loads it
// and exposes window.CKEDITOR / window.UploadFilesPlugin; a second copy
// raises "ckeditor-duplicated-modules". On the frontend application.js
// provides it.
//
//= require ../lib/content_block_editor_namespace
//= require sortablejs/Sortable.min.js
//
//= require ace-builds/src-min/ace
//= require ace-builds/src-noconflict/mode-html
//= require ace-builds/src-noconflict/worker-html
//
// require idiomorph/dist/idiomorph.js
//
//= require ../lib/files/filter_serializer
//= require ../html_editor
//= require ../custom/lib/Ajax
//= require ../custom/components/shared/modal
//= require ../custom/components/shared/dropdown_select_menu_component
//= require ../studio/image_gallery_fallback
//= require ../projekt_studio/main
//= require_tree ../projekt_studio/utils
//= require_tree ../projekt_studio/templates

//= require projekt_studio/modules/Sidebar
//= require ../projekt_studio/modules/Banner
//= require ../projekt_studio/modules/PhasesTabs
//= require ../projekt_studio/modules/ContentBlock/Render
//= require ../projekt_studio/modules/ContentBlock/DomHelpers
//= require ../projekt_studio/modules/ContentBlock/DragDrop
//= require ../projekt_studio/modules/ContentBlock/DraftStore
//= require ../projekt_studio/modules/ContentBlock/ChangeHistory
//= require ../custom/components/shared/tabs
//= require ../projekt_studio/modules/ContentBlockTemplateSelector
//= require ../projekt_studio/modules/ContentBlock/Crud
//= require ../projekt_studio/modules/ContentBlock/AiEditMode
//= require ../projekt_studio/modules/ContentBlock/DtAiEditMode
//= require ../projekt_studio/modules/ContentBlock/CodeEditMode
//= require ../projekt_studio/modules/ContentBlock/EditModeSwitcher
//= require ../projekt_studio/modules/ContentBlock/EditModeButtons
//= require ../projekt_studio/modules/ContentBlock/Copy
//= require ../projekt_studio/modules/ContentBlock/EmptyHintToggle
//= require ../projekt_studio/modules/ContentBlock/SimpleEditMode
//= require ../projekt_studio/modules/ContentBlock/SimpleEditMode/TextFormat
//= require ../projekt_studio/modules/ContentBlock/SimpleEditMode/HeaderEdit
//= require ../projekt_studio/modules/ContentBlock/SimpleEditMode/ListEdit
//= require ../projekt_studio/modules/ContentBlock/SimpleEditMode/LinkEdit
//= require ../projekt_studio/modules/ContentBlock/SimpleEditMode/ImageEdit
//= require ../projekt_studio/modules/ContentBlock/SimpleEditMode/FileManagerDialog
//= require ../projekt_studio/modules/ContentBlock/CKEditorMode
//= require ../projekt_studio/modules/SavedContentBlocks
//= require ../projekt_studio/modules/FileImport
//= require ../projekt_studio/modules/ProjektStart
//= require ../projekt_studio/modules/BuildWithPrompt
//= require ../projekt_studio/modules/CreateContentBlockWithAi
//= require ../projekt_studio/modules/ToggleBackground
//= require ../custom/components/studio
//= require ../custom/components/projekts/content_block_templates_selector_loader
//= require ../studio/newsletter_page
