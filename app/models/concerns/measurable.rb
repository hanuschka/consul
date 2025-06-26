module Measurable
  extend ActiveSupport::Concern

  class_methods do
    def title_max_length
      @title_max_length ||= columns.find { |c| c.name == "title" }&.limit || 80
    end

    def responsible_name_max_length
      @responsible_name_max_length ||= columns.find { |c| c.name == "responsible_name" }&.limit || 60
    end

    def question_max_length
      140
    end

    def description_max_length
      6000
    end

    def description_min_length
      10
    end
  end

  private

    def description_sanitized
      stripped = ActionController::Base.helpers.strip_tags(description)

      sanitized_description = stripped
        .delete("\n\r ")
        .gsub(/^$\n/, "")
        .gsub(/[\u202F\u00A0\u2000\u2001\u2003]/, "")

      max_length = projekt_phase.option("form.description_max_length").to_i

      errors.add(:description, :too_long) if
        sanitized_description.length > max_length
    end
end
