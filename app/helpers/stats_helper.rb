module StatsHelper
  def stat_value(number)
    formatted = number_with_delimiter(number)
    css = "adm-stat-card__value"
    css += " adm-stat-card__value--compact" if number.to_i >= 100_000
    tag.div formatted, class: css
  end

  def number_to_stats_percentage(number, options = {})
    number_to_percentage(number, { strip_insignificant_zeros: true, precision: 2 }.merge(options))
  end

  def number_with_info_tags(number, text, html_class: "")
    tag.p class: "number-with-info #{html_class}".strip do
      tag.span class: "content" do
        tag.span(number, class: "number") + tag.span(text, class: "info")
      end
    end
  end
end
