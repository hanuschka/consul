// Reads and edits single declarations of an element's style attribute as
// text. Assigning element.style.* instead re-serializes the whole attribute
// from the CSSOM, which drops fallback declarations such as
// "background: var(--brand-color); background: linear-gradient(...)".
// Values containing a semicolon (data URIs) are not supported.
App.Studio.utils.inlineDeclarationPattern = function(property, flags) {
  return new RegExp(`(^|;)(\\s*)${property}\\s*:([^;]*)`, flags);
}

// The value of the last declaration, the one the browser applies.
App.Studio.utils.inlineDeclaration = function(element, property) {
  const style = element.getAttribute("style") || "";
  const matches = Array.from(style.matchAll(App.Studio.utils.inlineDeclarationPattern(property, "gi")));

  if (matches.length === 0) return null

  return matches[matches.length - 1][3].trim()
}

App.Studio.utils.setInlineDeclaration = function(element, property, value) {
  const style = element.getAttribute("style") || "";
  let updatedStyle;

  if (App.Studio.utils.inlineDeclarationPattern(property, "i").test(style)) {
    updatedStyle = style.replace(
      App.Studio.utils.inlineDeclarationPattern(property, "gi"),
      `$1$2${property}: ${value}`
    );
  } else {
    updatedStyle = App.Studio.utils.appendInlineDeclaration(style, `${property}: ${value}`);
  }

  if (updatedStyle !== style) {
    element.setAttribute("style", updatedStyle);
  }
}

// Drops every declaration of the given properties and appends one
// declaration instead, e.g. all background longhands for one background.
App.Studio.utils.replaceInlineDeclarations = function(element, properties, declaration) {
  const style = element.getAttribute("style") || "";
  const remainingStyle = properties
    .reduce((currentStyle, property) => {
      return currentStyle.replace(App.Studio.utils.inlineDeclarationPattern(property, "gi"), "")
    }, style)
    .replace(/^\s*;\s*/, "");
  const updatedStyle = App.Studio.utils.appendInlineDeclaration(remainingStyle, declaration);

  if (updatedStyle !== style) {
    element.setAttribute("style", updatedStyle);
  }
}

App.Studio.utils.appendInlineDeclaration = function(style, declaration) {
  const trimmedStyle = style.trim().replace(/;$/, "");

  return trimmedStyle ? `${trimmedStyle}; ${declaration};` : `${declaration};`
}
