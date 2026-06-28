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
//= require ../custom/components/shared/image_cropper
//= require ../custom/components/shared/dropdown_select_menu_component
//= require ../studio/image_gallery_fallback
//= require ../studio/main
//= require_tree ../studio/utils
//= require_tree ../studio/templates

//= require studio/modules/Sidebar
//= require ../studio/modules/Banner
//= require ../studio/modules/PhasesTabs
//= require ../studio/modules/ContentBlock/Render
//= require ../studio/modules/ContentBlock/DomHelpers
//= require ../studio/modules/ContentBlock/DragDrop
//= require ../studio/modules/ContentBlock/DraftStore
//= require ../studio/modules/ContentBlock/ChangeHistory
//= require ../custom/components/shared/tabs
//= require ../studio/modules/ContentBlockTemplateSelector
//= require ../studio/modules/ContentBlock/Crud
//= require ../studio/modules/ContentBlock/MapEmbed
//= require ../studio/modules/ContentBlock/AiEditMode
//= require ../studio/modules/ContentBlock/CodeEditMode
//= require ../studio/modules/ContentBlock/EditModeSwitcher
//= require ../studio/modules/ContentBlock/EditModeButtons
//= require ../studio/modules/ContentBlock/CopyFeedback
//= require ../studio/modules/ContentBlock/Copy
//= require ../studio/modules/ContentBlock/EmptyHintToggle
//= require ../studio/modules/ContentBlock/SimpleEditMode
//= require ../studio/modules/ContentBlock/SimpleEditMode/EditPopup
//= require ../studio/modules/ContentBlock/SimpleEditMode/TextFormat
//= require ../studio/modules/ContentBlock/SimpleEditMode/HeaderEdit
//= require ../studio/modules/ContentBlock/SimpleEditMode/ListEdit
//= require ../studio/modules/ContentBlock/SimpleEditMode/LinkEdit
//= require ../studio/modules/ContentBlock/SimpleEditMode/ImageEdit
//= require ../studio/modules/ContentBlock/SimpleEditMode/MapEdit
//= require ../studio/modules/ContentBlock/SimpleEditMode/MapSourceEdit
//= require ../studio/modules/ContentBlock/SimpleEditMode/ImageAltEdit
//= require ../studio/modules/ContentBlock/SimpleEditMode/FileManagerDialog
//= require ../studio/modules/ContentBlock/CKEditorMode
//= require ../studio/modules/SavedContentBlocks
//= require ../studio/modules/FileImport
//= require ../studio/modules/ProjektStart
//= require ../studio/modules/BuildWithPrompt
//= require ../studio/modules/CreateContentBlockWithAi
//= require ../studio/modules/ToggleBackground
//= require ../custom/components/studio
//= require ../custom/components/projekts/content_block_templates_selector_loader
//= require ../studio/newsletter_page
