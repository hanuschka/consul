const STORAGE_KEY = "adm.flash.pending"
const AUTO_DISMISS_MS = 6000

export function addFlashMessage(message, variant = "info") {
  const container = document.getElementById("flash-messages")
  if (!container) return

  const safeVariant = ["success", "danger", "info"].includes(variant) ? variant : "info"
  const node = document.createElement("div")

  node.className = `kern-flash kern-flash--${safeVariant}`
  node.setAttribute("role", "alert")
  node.innerHTML = `
    <span></span>
    <button type="button" class="kern-flash__close" aria-label="Close">
      <span class="material-symbols-outlined">close</span>
    </button>
  `
  node.querySelector("span").textContent = message
  node.querySelector(".kern-flash__close").addEventListener("click", () => node.remove())
  container.appendChild(node)

  setTimeout(() => node.remove(), AUTO_DISMISS_MS)
}

export function queueFlashMessage(message, variant = "info") {
  try {
    const pending = JSON.parse(window.sessionStorage.getItem(STORAGE_KEY) || "[]")

    pending.push({ message, variant })
    window.sessionStorage.setItem(STORAGE_KEY, JSON.stringify(pending))
  } catch (e) {
    addFlashMessage(message, variant)
  }
}

export function flushQueuedFlashMessages() {
  try {
    const pending = JSON.parse(window.sessionStorage.getItem(STORAGE_KEY) || "[]")

    if (pending.length === 0) return

    window.sessionStorage.removeItem(STORAGE_KEY)
    pending.forEach((entry) => addFlashMessage(entry.message, entry.variant))
  } catch (e) {
    // ignore parse errors
  }
}
