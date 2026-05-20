// Entry point for the build script in your package.json

import "./controllers"

import "@hotwired/turbo-rails"

import { flushQueuedFlashMessages } from "./utils/adm_flash"

document.addEventListener("DOMContentLoaded", flushQueuedFlashMessages)
document.addEventListener("turbo:load", flushQueuedFlashMessages)
