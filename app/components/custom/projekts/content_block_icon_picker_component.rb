class Projekts::ContentBlockIconPickerComponent < ApplicationComponent
  # Editors find icons by German or English words, whatever the page locale
  SEARCH_LOCALES = %i[de en].freeze

  # Font Awesome 5 Free ships only a few icons in the regular style, so every
  # icon names the style prefix it exists in.
  ICON_GROUPS = {
    places: {
      "map-marker-alt" => "fas",
      "map-marker" => "fas",
      "map-pin" => "fas",
      "map" => "fas",
      "map-marked-alt" => "fas",
      "map-signs" => "fas",
      "compass" => "fas",
      "globe-europe" => "fas",
      "city" => "fas",
      "street-view" => "fas",
      "route" => "fas",
      "road" => "fas",
      "draw-polygon" => "fas",
      "layer-group" => "fas",
      "flag-checkered" => "fas",
      "bullseye" => "fas"
    },
    buildings: {
      "building" => "fas",
      "home" => "fas",
      "house-user" => "fas",
      "landmark" => "fas",
      "school" => "fas",
      "university" => "fas",
      "church" => "fas",
      "mosque" => "fas",
      "synagogue" => "fas",
      "store" => "fas",
      "warehouse" => "fas",
      "industry" => "fas",
      "hotel" => "fas",
      "monument" => "fas",
      "door-open" => "fas"
    },
    dates: {
      "calendar-alt" => "far",
      "calendar" => "far",
      "calendar-check" => "far",
      "calendar-plus" => "far",
      "calendar-times" => "far",
      "calendar-day" => "fas",
      "clock" => "far",
      "hourglass-half" => "fas",
      "stopwatch" => "fas",
      "history" => "fas",
      "bell" => "fas",
      "birthday-cake" => "fas"
    },
    people: {
      "user" => "fas",
      "users" => "fas",
      "user-friends" => "fas",
      "user-plus" => "fas",
      "user-check" => "fas",
      "user-tie" => "fas",
      "user-graduate" => "fas",
      "child" => "fas",
      "baby" => "fas",
      "baby-carriage" => "fas",
      "female" => "fas",
      "male" => "fas",
      "people-arrows" => "fas",
      "universal-access" => "fas",
      "wheelchair" => "fas",
      "blind" => "fas",
      "deaf" => "fas",
      "sign-language" => "fas",
      "id-card" => "far",
      "smile" => "far"
    },
    participation: {
      "comments" => "far",
      "comment-dots" => "far",
      "lightbulb" => "far",
      "thumbs-up" => "far",
      "thumbs-down" => "far",
      "handshake" => "far",
      "vote-yea" => "fas",
      "bullhorn" => "fas",
      "hands-helping" => "fas",
      "poll" => "fas",
      "poll-h" => "fas",
      "chart-bar" => "far",
      "chart-pie" => "fas",
      "chart-line" => "fas",
      "balance-scale" => "fas",
      "clipboard-check" => "fas",
      "tasks" => "fas",
      "check-square" => "far",
      "question" => "fas",
      "hand-paper" => "far",
      "award" => "fas"
    },
    communication: {
      "comment" => "far",
      "envelope" => "far",
      "envelope-open-text" => "fas",
      "paper-plane" => "far",
      "inbox" => "fas",
      "at" => "fas",
      "phone-alt" => "fas",
      "mobile-alt" => "fas",
      "headset" => "fas",
      "microphone" => "fas",
      "share-alt" => "fas",
      "link" => "fas",
      "external-link-alt" => "fas",
      "reply" => "fas",
      "language" => "fas",
      "globe" => "fas",
      "qrcode" => "fas"
    },
    documents: {
      "file-alt" => "far",
      "file" => "far",
      "file-pdf" => "far",
      "file-word" => "far",
      "file-excel" => "far",
      "file-signature" => "fas",
      "folder" => "far",
      "folder-open" => "far",
      "clipboard-list" => "fas",
      "book-open" => "fas",
      "book" => "fas",
      "print" => "fas",
      "paperclip" => "fas",
      "edit" => "far",
      "pencil-alt" => "fas",
      "list-ul" => "fas",
      "list-ol" => "fas",
      "quote-left" => "fas",
      "download" => "fas",
      "upload" => "fas"
    },
    media: {
      "video" => "fas",
      "film" => "fas",
      "play" => "fas",
      "closed-captioning" => "far",
      "image" => "far",
      "images" => "far",
      "camera" => "fas",
      "volume-up" => "fas",
      "th-large" => "fas",
      "laptop" => "fas",
      "desktop" => "fas",
      "newspaper" => "far"
    },
    transport: {
      "bus" => "fas",
      "train" => "fas",
      "subway" => "fas",
      "tram" => "fas",
      "bicycle" => "fas",
      "biking" => "fas",
      "car" => "fas",
      "taxi" => "fas",
      "truck" => "fas",
      "motorcycle" => "fas",
      "plane" => "fas",
      "ship" => "fas",
      "walking" => "fas",
      "shoe-prints" => "fas",
      "charging-station" => "fas",
      "traffic-light" => "fas",
      "parking" => "fas"
    },
    nature: {
      "tree" => "fas",
      "leaf" => "fas",
      "seedling" => "fas",
      "water" => "fas",
      "tint" => "fas",
      "sun" => "fas",
      "cloud" => "fas",
      "cloud-sun" => "fas",
      "cloud-rain" => "fas",
      "snowflake" => "far",
      "wind" => "fas",
      "mountain" => "fas",
      "fish" => "fas",
      "dog" => "fas",
      "paw" => "fas",
      "dove" => "fas",
      "recycle" => "fas",
      "trash-alt" => "far",
      "solar-panel" => "fas",
      "bolt" => "fas",
      "fire" => "fas",
      "apple-alt" => "fas"
    },
    health: {
      "heartbeat" => "fas",
      "hospital" => "fas",
      "clinic-medical" => "fas",
      "first-aid" => "fas",
      "stethoscope" => "fas",
      "pills" => "fas",
      "syringe" => "fas",
      "ambulance" => "fas",
      "user-nurse" => "fas",
      "user-md" => "fas",
      "hand-holding-heart" => "fas",
      "hands-wash" => "fas",
      "head-side-mask" => "fas"
    },
    education: {
      "graduation-cap" => "fas",
      "chalkboard-teacher" => "fas",
      "book-reader" => "fas",
      "pencil-ruler" => "fas",
      "microscope" => "fas",
      "flask" => "fas",
      "palette" => "fas",
      "paint-brush" => "fas",
      "music" => "fas",
      "guitar" => "fas",
      "theater-masks" => "fas",
      "ticket-alt" => "fas",
      "puzzle-piece" => "fas"
    },
    leisure: {
      "futbol" => "far",
      "basketball-ball" => "fas",
      "swimmer" => "fas",
      "running" => "fas",
      "hiking" => "fas",
      "dumbbell" => "fas",
      "campground" => "fas",
      "umbrella-beach" => "fas",
      "gamepad" => "fas",
      "dice" => "fas",
      "coffee" => "fas",
      "utensils" => "fas",
      "pizza-slice" => "fas",
      "ice-cream" => "fas",
      "glass-cheers" => "fas",
      "gift" => "fas"
    },
    work: {
      "hammer" => "fas",
      "hard-hat" => "fas",
      "tools" => "fas",
      "wrench" => "fas",
      "toolbox" => "fas",
      "paint-roller" => "fas",
      "ruler-combined" => "fas",
      "drafting-compass" => "fas",
      "briefcase" => "fas",
      "cog" => "fas",
      "tractor" => "fas",
      "truck-loading" => "fas"
    },
    money: {
      "euro-sign" => "fas",
      "coins" => "fas",
      "money-bill-wave" => "fas",
      "wallet" => "fas",
      "piggy-bank" => "fas",
      "credit-card" => "far",
      "receipt" => "fas",
      "calculator" => "fas",
      "percent" => "fas",
      "shopping-cart" => "fas",
      "shopping-bag" => "fas",
      "tag" => "fas"
    },
    safety: {
      "shield-alt" => "fas",
      "user-shield" => "fas",
      "lock" => "fas",
      "lock-open" => "fas",
      "key" => "fas",
      "fire-extinguisher" => "fas",
      "exclamation-triangle" => "fas",
      "eye" => "far",
      "eye-slash" => "far",
      "life-ring" => "far",
      "ban" => "fas"
    },
    symbols: {
      "check-circle" => "fas",
      "times-circle" => "fas",
      "check" => "fas",
      "times" => "fas",
      "plus" => "fas",
      "minus" => "fas",
      "minus-circle" => "fas",
      "arrow-right" => "fas",
      "arrow-left" => "fas",
      "arrow-up" => "fas",
      "arrow-down" => "fas",
      "arrows-alt-h" => "fas",
      "exchange-alt" => "fas",
      "chevron-right" => "fas",
      "star" => "fas",
      "heart" => "far",
      "bookmark" => "far",
      "flag" => "fas",
      "thumbtack" => "fas",
      "info-circle" => "fas",
      "info" => "fas",
      "exclamation-circle" => "fas",
      "exclamation" => "fas",
      "question-circle" => "far",
      "hashtag" => "fas",
      "search" => "fas"
    }
  }.freeze

  # Built once per process and locale, as it takes about 1,400 translation
  # lookups; translations change only with a deploy, which restarts it
  ICON_GROUPS_BY_LOCALE = Concurrent::Map.new

  def icon_groups
    ICON_GROUPS_BY_LOCALE.compute_if_absent(I18n.locale) { build_icon_groups }
  end

  private

  def build_icon_groups
    ICON_GROUPS.map do |group_key, icons|
      {
        key: group_key,
        title: t("custom.projekts.page.content_block_icon_picker.groups.#{group_key}"),
        icons: icons.map { |icon_name, icon_style| icon_option(icon_name, icon_style) }
      }
    end
  end

  def icon_option(icon_name, icon_style)
    translation_key = icon_name.tr("-", "_")

    {
      name: icon_name,
      style: icon_style,
      label: t("custom.projekts.page.content_block_icon_picker.icons.#{translation_key}"),
      search_terms: search_terms(icon_name, translation_key)
    }
  end

  def search_terms(icon_name, translation_key)
    translated_terms = SEARCH_LOCALES.flat_map do |locale|
      [
        t("custom.projekts.page.content_block_icon_picker.icons.#{translation_key}", locale: locale),
        t("custom.projekts.page.content_block_icon_picker.keywords.#{translation_key}", locale: locale)
      ]
    end

    [icon_name.tr("-", " "), *translated_terms].join(" ")
  end
end
