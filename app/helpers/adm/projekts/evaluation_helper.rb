module Adm::Projekts::EvaluationHelper
  CHART_PALETTE = %w[
    #1E40AF #059669 #D97706 #7C3AED
    #DB2777 #0891B2 #DC2626 #65A30D
  ].freeze

  EVALUATION_AI_SECTIONS = %w[
    phase_summary
    tone
    label_sentiment
    ai_summary
    key_findings
    topic_clustering
    semantic_clustering
    ai_questions
  ].freeze

  def evaluation_ai_section_keys
    EVALUATION_AI_SECTIONS
  end

  def evaluation_section_tabs(section_key)
    key = section_key.to_s

    if EVALUATION_AI_SECTIONS.include?(key)
      "ai"
    else
      "stats"
    end
  end

  def evaluation_section_has_data?(phase, section_key)
    ::ProjektEvaluations::SectionDataPresence.has_data?(phase, section_key)
  end

  def evaluation_visibility_subgroups(available_sections)
    ai_sections = Ai::Settings.ai_available? ? (available_sections & EVALUATION_AI_SECTIONS) : []

    [
      {
        key: "stats",
        icon: "monitoring",
        label_key: "adm.projekts.projekts.evaluation.view_tabs.stats",
        sections: available_sections - EVALUATION_AI_SECTIONS
      },
      {
        key: "ai",
        icon: "auto_awesome",
        label_key: "adm.projekts.projekts.evaluation.view_tabs.ai",
        sections: ai_sections
      }
    ]
  end

  def evaluation_chart_colors(values, base_colors = nil)
    source = base_colors.presence || CHART_PALETTE

    values.each_index.map { |index| source[index % source.size] }
  end

  def evaluation_phase_palette
    palette = {
      "ProjektPhase::ProposalPhase" => {
        accent: "#059669",
        accent_light: "#D1FAE5",
        shades: ["#059669", "#10B981", "#34D399", "#6EE7B7", "#A7F3D0", "#D1FAE5"]
      },
      "ProjektPhase::VotingPhase" => {
        accent: "#1E40AF",
        accent_light: "#DBEAFE",
        shades: ["#1E40AF", "#1E3A8A", "#3B82F6", "#60A5FA", "#93C5FD", "#DBEAFE"]
      },
      "ProjektPhase::BudgetPhase" => {
        accent: "#D97706",
        accent_light: "#FEF3C7",
        shades: ["#D97706", "#F59E0B", "#FBBF24", "#FCD34D", "#FDE68A", "#FEF3C7"]
      },
      "ProjektPhase::CommentPhase" => {
        accent: "#7C3AED",
        accent_light: "#EDE9FE",
        shades: ["#7C3AED", "#8B5CF6", "#A78BFA", "#C4B5FD", "#DDD6FE", "#EDE9FE"]
      }
    }
    palette.default = palette["ProjektPhase::ProposalPhase"]

    palette
  end

  def evaluation_phase_kpi_config
    {
      "ProjektPhase::ProposalPhase" => {
        kpi_key: "proposals_count",
        kpi_label_key: "adm.projekts.projekts.evaluation.proposals",
        subtitle_key: "adm.projekts.projekts.evaluation.proposal_phase"
      },
      "ProjektPhase::VotingPhase" => {
        kpi_key: "participants_count",
        kpi_label_key: "adm.projekts.projekts.evaluation.participants",
        subtitle_key: "adm.projekts.projekts.evaluation.voting_phase"
      },
      "ProjektPhase::BudgetPhase" => {
        kpi_key: "investments_count",
        kpi_label_key: "adm.projekts.projekts.evaluation.investments",
        subtitle_key: "adm.projekts.projekts.evaluation.budget_phase"
      },
      "ProjektPhase::CommentPhase" => {
        kpi_key: "comments_count",
        kpi_label_key: "adm.projekts.projekts.evaluation.comments",
        subtitle_key: "adm.projekts.projekts.evaluation.comment_phase"
      }
    }
  end

  def evaluation_phase_section_partial
    {
      "ProjektPhase::ProposalPhase" => "proposal_phase_section",
      "ProjektPhase::VotingPhase" => "voting_phase_section",
      "ProjektPhase::BudgetPhase" => "budget_phase_section",
      "ProjektPhase::CommentPhase" => "comment_phase_section"
    }
  end

  def phase_summary_sections(short_summary)
    case short_summary
    when Array
      short_summary.filter_map do |section|
        next if !section.is_a?(Hash)

        body = (section["body"] || section[:body]).to_s.strip
        next if body.blank?

        heading = (section["heading"] || section[:heading]).to_s.strip

        { "heading" => heading.presence, "body" => body }
      end
    when String
      text = short_summary.strip
      text.present? ? [{ "heading" => nil, "body" => text }] : []
    else
      []
    end
  end

  def phase_summary_plain_text(short_summary)
    sections = phase_summary_sections(short_summary)
    return nil if sections.empty?

    sections.map { |section| section["body"] }.join(" ")
  end

  def evaluation_plain_text(html_or_text)
    return "" if html_or_text.blank?

    with_spaces = html_or_text.to_s.gsub(%r{</(?:h3|p)>}i, " ")

    strip_tags(with_spaces).squish
  end

  def phase_has_ai_content?(phase)
    ai_stats = phase["ai_stats"] || {}

    ai_stats["summary"].present? ||
      ai_stats["topic_clustering"].present? ||
      ai_stats["semantic_clustering"].present? ||
      phase["key_findings"].present? ||
      phase["evaluation_summary"].present?
  end
end
