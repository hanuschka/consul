class ProjektImports::BuildInitialMessageService < ApplicationService
  attr_reader :projekt_import

  def initialize(projekt_import:)
    @projekt_import = projekt_import
  end

  def call
    data = projekt_import.ai_result

    if data.blank?
      return ServiceResult.failure(error: I18n.t("adm.projekts.imports.errors.no_ai_result"))
    end

    ServiceResult.success(content: build_message(data))
  end

  private

  def build_message(data)
    lines = []
    lines << "## #{t(:analysis_complete)}"
    lines << ""
    lines << t(:analysis_intro)
    lines << ""
    lines << "**#{t(:title)}:** #{data['title']}"
    lines << "**#{t(:subtitle)}:** #{data['subtitle']}" if data["subtitle"].present?
    lines << ""

    if data["projekt_start_date"].present? || data["projekt_end_date"].present?
      date_parts = []
      date_parts << format_date(data["projekt_start_date"]) if data["projekt_start_date"].present?
      date_parts << format_date(data["projekt_end_date"]) if data["projekt_end_date"].present?
      lines << "**#{t(:period)}:** #{date_parts.join(' – ')}"
    end

    if data["categories"].present?
      lines << "**#{t(:categories)}:** #{data['categories'].join(', ')}"
    end

    if data["phases"].present?
      lines << ""
      lines << "### #{t(:phases)}"

      data["phases"].each do |phase|
        phase_text = "- **#{phase['name'] || phase['type']}**"
        dates = [phase["start_date"], phase["end_date"]].compact
        phase_text += " (#{dates.map { |d| format_date(d) }.join(' – ')})" if dates.any?
        lines << phase_text
      end
    end

    if data["content_blocks"].present?
      lines << ""
      lines << "**#{t(:content_blocks)}:** #{data['content_blocks'].length} #{t(:created)}"
    end

    lines << ""
    lines << "---"
    lines << ""

    if data["clarification_questions"].present?
      lines << t(:questions_intro)
      lines << ""

      data["clarification_questions"].each do |question|
        lines << "- #{question}"
      end

      lines << ""
      lines << t(:questions_outro)
    else
      lines << t(:review_outro)
    end

    lines.join("\n")
  end

  def t(key)
    I18n.t("adm.projekts.imports.initial_message.#{key}")
  end

  def format_date(date_string)
    Date.parse(date_string).strftime("%d.%m.%Y")
  rescue StandardError
    date_string
  end
end
