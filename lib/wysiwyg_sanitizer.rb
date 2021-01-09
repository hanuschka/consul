class WYSIWYGSanitizer
  def allowed_tags
    %w[p ul ol li strong em u s a h2 h3 div iframe]
  end

  def allowed_attributes
    %w[href class id target onclick cke_widget_wrapper cke_widget_block cke_widget_MJAccordion cke_widget_wrapper_mj_accordion]
  end

  def sanitize(html)
    ActionController::Base.helpers.sanitize(html, tags: allowed_tags, attributes: allowed_attributes)
  end
end