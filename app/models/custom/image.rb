require_dependency Rails.root.join("app", "models", "image").to_s

class Image
  before_save :clear_ai_generated_on_replaced_attachment

  # Writers that mean to keep or set the marker assign it in the same save; a
  # path that only swaps the file (the /adm banner upload, an API update that
  # omits the key) leaves it untouched, and the marker must not survive onto a
  # picture nobody declared.
  def ai_generated=(value)
    @ai_generated_assigned = true
    super
  end

  private

    def clear_ai_generated_on_replaced_attachment
      # The declaration counts for one save, so it is consumed here rather than
      # left for the next save of the same in-memory record to inherit.
      declared = @ai_generated_assigned
      @ai_generated_assigned = false

      return if declared
      return if !ai_generated?
      return if attachment_changes["attachment"].blank?

      self.ai_generated = false
      @ai_generated_assigned = false
    end
end
