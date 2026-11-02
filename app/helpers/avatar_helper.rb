module AvatarHelper
  AVATAR_COLORS = %w[
    #1abc9c #16a085 #f1c40f #f39c12 #2ecc71 #27ae60 #e67e22 #d35400 #3498db
    #2980b9 #e74c3c #c0392b #9b59b6 #8e44ad #bdc3c7 #34495e #2c3e50 #95a5a6
    #7f8c8d #ec87bf #d870ad #f69785 #9ba37e #b49255 #b49255 #a94136
  ].freeze
  AVATAR_FONT_FAMILY = [
    "HelveticaNeue-Light", "Helvetica Neue Light", "Helvetica Neue", "Helvetica", "Arial",
    "Lucida Grande", "sans-serif"
  ].join(", ").freeze

  def avatar_image(avatarable, options = {})
    name = avatarable.is_a?(String) ? avatarable : avatarable.name.to_s
    svg = avatar_svg(name.first.to_s.upcase, options.fetch(:size, 100), options[:seed].to_i)

    tag.img(
      src: "data:image/svg+xml;base64,#{Base64.strict_encode64(svg)}",
      alt: name,
      class: ["initials-avatar", options[:class]].compact_blank.join(" ")
    )
  end

  private

    def avatar_svg(initial, size, seed)
      svg_style = [
        "background-color: #{avatar_color(initial, seed)};",
        "width: #{size}px;",
        "height: #{size}px;",
        "border-radius: #{(size * 0.13).round}px;"
      ].join(" ")
      initial_tag = tag.text(
        initial,
        "text-anchor": "middle",
        y: "50%",
        x: "50%",
        dy: "0.35em",
        "pointer-events": "auto",
        fill: "#ffffff",
        "font-family": AVATAR_FONT_FAMILY,
        style: "font-weight: 400; font-size: #{(size * 0.6).round}px;"
      )

      tag.svg(
        initial_tag,
        xmlns: "http://www.w3.org/2000/svg",
        "pointer-events": "none",
        width: size,
        height: size,
        style: svg_style
      ).to_str
    end

    def avatar_color(initial, seed)
      return if initial.blank?

      AVATAR_COLORS[(initial.ord + seed) % AVATAR_COLORS.size]
    end
end
