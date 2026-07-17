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
//= require ../lib/studio_namespace
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
//= require ../studio/Evaluation/base
//= require ../studio/PreviewMode/base
//= require ../studio/Projekt/PageBrandColorPicker
//= require_tree ../studio/utils
//= require_tree ../studio/templates

//= require studio/Projekt/Sidebar
//= require ../studio/Projekt/Banner
//= require ../studio/Projekt/PhasesTabs
//= require ../studio/ContentBlocks/Render
//= require ../studio/ContentBlocks/DomHelpers
//= require ../studio/ContentBlocks/DragDrop
//= require ../studio/ContentBlocks/DraftStore
//= require ../studio/ContentBlocks/ChangeHistory
//= require ../custom/components/shared/tabs
//= require ../studio/ContentBlocks/TemplateSelector
//= require ../studio/ContentBlocks/Crud
//= require ../studio/ContentBlocks/MapEmbed
//= require ../studio/ContentBlocks/EditModes/AiEditMode
//= require ../studio/ContentBlocks/EditModes/CodeEditMode
//= require ../studio/ContentBlocks/EditModes/EditModeSwitcher
//= require ../studio/ContentBlocks/EditModes/EditModeButtons
//= require ../studio/ContentBlocks/CopyFeedback
//= require ../studio/ContentBlocks/Copy
//= require ../studio/ContentBlocks/EmptyHintToggle
//= require ../studio/ContentBlocks/EditModes/SimpleEditMode
//= require ../studio/ContentBlocks/EditModes/SimpleEditMode/EditPopup
//= require ../studio/ContentBlocks/EditModes/SimpleEditMode/TextFormat
//= require ../studio/ContentBlocks/EditModes/SimpleEditMode/HeaderEdit
//= require ../studio/ContentBlocks/EditModes/SimpleEditMode/ListEdit
//= require ../studio/ContentBlocks/EditModes/SimpleEditMode/LinkEdit
//= require ../studio/ContentBlocks/EditModes/SimpleEditMode/ImageEdit
//= require ../studio/ContentBlocks/EditModes/SimpleEditMode/MapEdit
//= require ../studio/ContentBlocks/EditModes/SimpleEditMode/MapSourceEdit
//= require ../studio/ContentBlocks/EditModes/SimpleEditMode/ImageAltEdit
//= require ../studio/ContentBlocks/EditModes/SimpleEditMode/FileManagerDialog
//= require ../studio/ContentBlocks/EditModes/CKEditorMode
//= require ../studio/ContentBlocks/SavedContentBlocks
//= require ../studio/Projekt/AiFileImport
//= require ../studio/Projekt/ProjektStart
//= require ../studio/Projekt/AiBuildWithPrompt
//= require ../studio/ContentBlocks/CreateContentBlockWithAi
//= require ../studio/Projekt/ToggleBackground
//= require ../custom/components/studio
//= require ../custom/components/projekts/content_block_templates_selector_loader
//= require ../studio/newsletter_page
