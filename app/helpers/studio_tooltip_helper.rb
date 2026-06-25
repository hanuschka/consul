module StudioTooltipHelper
  def studio_rich_tooltip(title:, text: nil, note: nil, delay: nil, placement: nil, &block)
    trigger = capture(&block)

    body = content_tag(:div, class: "rich-tooltip-content") do
      parts = [content_tag(:span, title, class: "rich-tooltip-content--title")]
      parts << content_tag(:span, text, class: "rich-tooltip-content--text") if text.present?
      parts << content_tag(:span, note, class: "rich-tooltip-content--note") if note.present?

      safe_join(parts)
    end

    options = { "trigger-only" => "" }
    options["delay"] = delay if delay.present?
    options["placement"] = placement if placement.present?

    content_tag("rich-tooltip", safe_join([trigger, content_tag(:template, body)]), options)
  end
end
