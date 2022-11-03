module Loofah
  module HTML5
    module SafeList
      ADDITIONAL_ACCEPTABLE_CSS_PROPERTIES = Set.new([
                                  "position",
                                  "max-height",
                                  "min-height",
                                ])

      ALLOWED_CSS_PROPERTIES = ACCEPTABLE_CSS_PROPERTIES + ADDITIONAL_ACCEPTABLE_CSS_PROPERTIES
    end
  end
end
