module KernHelper
  def kern_submit_button(icon: nil, text: nil, autofocus: false)
    button_tag(type: "submit", class: "kern-btn kern-btn--primary", autofocus: autofocus) do
      if icon.present?
        concat(content_tag(:span, icon, class: "kern-label material-symbols-outlined", "aria-hidden": "true"))
      end
      concat(content_tag(:span, text, class: "kern-label")) if text.present?
    end
  end
end
