// Entry point for the build script in your package.json

import "./controllers"

import "@hotwired/turbo-rails"

import { flushQueuedFlashMessages } from "./utils/adm_flash"
import { revealIconsWhenFontLoaded } from "./utils/icon_font_loading"

revealIconsWhenFontLoaded()

document.addEventListener("DOMContentLoaded", flushQueuedFlashMessages)
document.addEventListener("turbo:load", flushQueuedFlashMessages)
