# Extends Loofah's CSS safelist used by Rails' sanitize helper (ActionView/ActionController).
# Fixes sanitization issues in AdminWYSIWYGSanitizer and allows to use extra css attributes and functions

# Allow positioning-related inline CSS in sanitized content.
extra_properties = %w[position top bottom left right box-shadow border-radius z-index]

if defined?(Loofah::HTML5::SafeList::ALLOWED_CSS_PROPERTIES)
  Loofah::HTML5::SafeList::ALLOWED_CSS_PROPERTIES.merge(extra_properties)
end

if defined?(Loofah::HTML4::SafeList::ALLOWED_CSS_PROPERTIES)
  Loofah::HTML4::SafeList::ALLOWED_CSS_PROPERTIES.merge(extra_properties)
end

# Allow CSS functions used in custom design tokens (e.g. background-color: var(--brand-color),
# color: mix(...)).  Without these, values using var() or mix() are stripped on sanitize.
if defined?(Loofah::HTML5::SafeList::ALLOWED_CSS_FUNCTIONS)
  Loofah::HTML5::SafeList::ALLOWED_CSS_FUNCTIONS.add("var")
  Loofah::HTML5::SafeList::ALLOWED_CSS_FUNCTIONS.add("mix")
end
