const STORAGE_PREFIX = "adm.list-state:"

function storageKey(pagePath, frameId) {
  return `${STORAGE_PREFIX}${pagePath}#${frameId}`
}

export function readListState(pagePath, frameId) {
  try {
    return window.sessionStorage.getItem(storageKey(pagePath, frameId))
  } catch (e) {
    return null
  }
}

export function writeListState(pagePath, frameId, url) {
  try {
    window.sessionStorage.setItem(storageKey(pagePath, frameId), url)
  } catch (e) {}
}

export function forgetAllListStates() {
  try {
    Object.keys(window.sessionStorage)
      .filter(key => key.startsWith(STORAGE_PREFIX))
      .forEach(key => window.sessionStorage.removeItem(key))
  } catch (e) {}
}
