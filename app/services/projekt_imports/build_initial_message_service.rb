class ProjektImports::BuildInitialMessageService < ApplicationService
  VOTING_PHASE_TYPE = "ProjektPhase::VotingPhase".freeze

  attr_reader :projekt_import, :text_truncated

  def initialize(projekt_import:, text_truncated: false)
    @projekt_import = projekt_import
    @text_truncated = text_truncated
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

    if text_truncated
      lines << "**⚠️ #{t(:input_truncated_notice)}**"
      lines << ""
    end
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

      empty_voting_phase = false

      data["phases"].each do |phase|
        phase_text = "- **#{phase['name'] || phase['type']}**"
        dates = [phase["start_date"], phase["end_date"]].compact
        phase_text += " (#{dates.map { |d| format_date(d) }.join(' – ')})" if dates.any?

        if voting_phase?(phase)
          question_count = poll_question_count(phase)
          empty_voting_phase ||= question_count.zero?
          phase_text += " — #{poll_question_summary(question_count)}"
        end

        lines << phase_text
      end

      if empty_voting_phase
        lines << ""
        lines << "**⚠️ #{t(:no_poll_questions_notice)}**"
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

      data["clarification_questions"].each_with_index do |question, index|
        clean_question = question.to_s.strip.sub(/\A\d+[.)]\s*/, "")
        lines << "- #{index + 1}\\. #{clean_question}"
      end

      lines << ""
      lines << t(:questions_outro)
    else
      lines << t(:review_outro)
    end

    lines.join("\n")
  end

  def voting_phase?(phase)
    phase["type"] == VOTING_PHASE_TYPE
  end

  def poll_question_count(phase)
    Array(phase["poll_questions"]).count { |question| question["title"].present? }
  end

  def poll_question_summary(question_count)
    I18n.t(
      "adm.projekts.imports.initial_message.poll_questions_count",
      count: question_count
    )
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
