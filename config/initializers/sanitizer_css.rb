# Extends Loofah's CSS safelist used by Rails' sanitize helper (ActionView/ActionController).
# Fixes sanitization issues in AdminWYSIWYGSanitizer and allows extra css properties and functions.

# Allow ALL inline CSS property NAMES. Loofah still applies value-level scrubbing
# on every declaration: url()/bad_url tokens are always rejected and any CSS
# function not in ALLOWED_CSS_FUNCTIONS is dropped. So the script-execution
# vectors (expression(), behavior:url(), -moz-binding, url(javascript:)) stay
# blocked; only the property-name allowlist is lifted. Authored content is
# admin/PM only.
[
  defined?(Loofah::HTML5::SafeList::ALLOWED_CSS_PROPERTIES) && Loofah::HTML5::SafeList::ALLOWED_CSS_PROPERTIES,
  defined?(Loofah::HTML4::SafeList::ALLOWED_CSS_PROPERTIES) && Loofah::HTML4::SafeList::ALLOWED_CSS_PROPERTIES
].each do |property_set|
  next unless property_set

  def property_set.include?(_property)
    true
  end
end

# Allow additional CSS functions for design tokens and modern color/math/grid syntax.
# Loofah's defaults cover gradients, transforms, filters, calc(), rgb()/hsl(),
# attr(), counter(), etc. but NOT var()/mix() nor the modern math/color/grid
# functions below. url()-bearing values stay rejected by Loofah's url_flags check
# regardless of this list, and expression() is intentionally never added
# (script-execution vector).
extra_functions = %w[
  var mix
  min max clamp
  conic-gradient repeating-conic-gradient
  lab lch oklab oklch color color-mix
  minmax repeat fit-content
  env steps
]

[
  defined?(Loofah::HTML5::SafeList::ALLOWED_CSS_FUNCTIONS) && Loofah::HTML5::SafeList::ALLOWED_CSS_FUNCTIONS,
  defined?(Loofah::HTML4::SafeList::ALLOWED_CSS_FUNCTIONS) && Loofah::HTML4::SafeList::ALLOWED_CSS_FUNCTIONS
].each do |function_set|
  next unless function_set

  function_set.merge(extra_functions)
end
