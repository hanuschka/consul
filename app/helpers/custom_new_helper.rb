module CustomNewHelper
  def resources_back_link(fallback_path:)
    if params[:origin] == "projekt" && params[:projekt_phase_id].present?
      link_to(url_to_footer_tab, class: "back") do
        tag.span(class: "icon-angle-left") + t("shared.back")
      end
    else
      back_path =
        if session[:back_path].present? && session[:back_path] != request.fullpath
          session[:back_path]
        else
          fallback_path
        end

      back_link_to(back_path)
    end
  end

  def custom_new_design_body_class
    css_class = Setting.new_design_enabled? ? "custom-new-design" : ""

    if embedded?
      css_class += " -embedded"
    end

    css_class
  end

  def sentiment_color_style(sentiment)
    if sentiment.present?
      "background-color:#{sentiment.color};color: #{pick_text_color(sentiment.color)}"
    end
  end

  def setting
    Setting.all_settings_hash
  end

  def google_translate_accepted?
    return false if cookies[:klaro].blank? || !cookies[:klaro].is_a?(String)

    begin
      parsed_data = JSON.parse(cookies[:klaro])
      parsed_data.is_a?(Hash) && parsed_data["google_translate_accepted"] == true
    rescue JSON::ParserError, ArgumentError => e
      Sentry.capture_exception(e)
      false
    end
  end
end
