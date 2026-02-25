if defined?(IRB)
  unless Rails.env.development?
    IRB.conf[:USE_AUTOCOMPLETE] = false
  end
end
