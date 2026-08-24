require_dependency Rails.root.join("app", "models", "image").to_s

class Image
  before_save :clear_ai_generated_on_replaced_attachment
  after_save :forget_ai_generated_assignment

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
      return if @ai_generated_assigned
      return if !persisted? || !ai_generated?
      return if attachment_changes["attachment"].blank?

      self.ai_generated = false
    end

    # The assignment counts for one save only, so a second save of the same
    # in-memory record does not inherit the first save's declaration.
    def forget_ai_generated_assignment
      @ai_generated_assigned = false
    end
end
