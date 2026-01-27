# Allow positioning-related inline CSS in sanitized content.
extra_properties = %w[position top bottom left right box-shadow border-radius z-index]

if defined?(Loofah::HTML5::SafeList::ALLOWED_CSS_PROPERTIES)
  Loofah::HTML5::SafeList::ALLOWED_CSS_PROPERTIES.merge(extra_properties)
end

if defined?(Loofah::HTML4::SafeList::ALLOWED_CSS_PROPERTIES)
  Loofah::HTML4::SafeList::ALLOWED_CSS_PROPERTIES.merge(extra_properties)
end
