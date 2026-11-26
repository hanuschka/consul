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
      max_length = (projekt_phase&.option("form.description_max_length").presence || "6000").to_i

      if measured_descriptions.any? { sanitized_description_length(it) > max_length }
        errors.add(:description, :too_long)
      end
    end

    def measured_descriptions
      written_descriptions = globalize.stash.filter_map do |locale, attributes|
        attributes["description"] if globalize.changes(locale).key?("description")
      end
      nested_descriptions = translations.select(&:description_changed?).map(&:description)

      [description, *written_descriptions, *nested_descriptions].compact
    end

    def sanitized_description_length(text)
      ActionController::Base.helpers.strip_tags(text)
        .delete("\n\r ")
        .gsub(/^$\n/, "")
        .gsub(/[\u202F\u00A0\u2000\u2001\u2003]/, "")
        .length
    end
end
