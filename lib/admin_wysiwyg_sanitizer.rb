class AdminWYSIWYGSanitizer < WYSIWYGSanitizer
  def allowed_tags
    super + %w[img table caption thead tbody tr th td div iframe]
  end

  def allowed_attributes
    super + %w[alt src align border cellpadding cellspacing dir style class summary scope id]
  end
end
