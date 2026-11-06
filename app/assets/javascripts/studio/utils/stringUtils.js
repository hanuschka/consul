// Lowercases and drops accents, so "Gebäude", "gebaude" and "GEBÄUDE" match
App.Studio.utils.normalizeSearchText = function(text) {
  return text
    .toLowerCase()
    .replace(/ß/g, "ss")
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
}
