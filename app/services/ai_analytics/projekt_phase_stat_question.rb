class AiAnalytics::ProjektPhaseStatQuestion < ApplicationService
  attr_reader :stat_question, :projekt_phase

  def initialize(stat_question)
    @stat_question = stat_question
    @projekt_phase = stat_question.projekt_phase
  end

  def call
    resources = get_resources(projekt_phase)

    if resources.empty?
      stat_question.update!(status: :failed, answer: no_resources_message)
      return
    end

    Rails.logger.info("[AI Analytics] ProjektPhaseStatQuestion: Starting for question ##{stat_question.id}")
    stat_question.update!(status: :processing)

    answer = generate_answer(resources)
    stat_question.update!(status: :completed, answer:)

    Rails.logger.info("[AI Analytics] ProjektPhaseStatQuestion: Completed for question ##{stat_question.id}")
  rescue => e
    Rails.logger.error("[AI Analytics] ProjektPhaseStatQuestion failed: #{e.message}")
    stat_question.update!(status: :failed, answer: error_message)
  end

  private

    def target_language
      Rails.env.development? ? "English" : "German"
    end

    def no_resources_message
      I18n.t("custom.participation_stats.ai_question.no_resources")
    end

    def error_message
      I18n.t("custom.participation_stats.ai_question.error")
    end

    def get_resources(projekt_phase)
      case projekt_phase
      when ProjektPhase::ProposalPhase
        projekt_phase.resources.base_selection.includes(:author, comments: :user)
      when ProjektPhase::BudgetPhase
        return [] if projekt_phase.budget.blank?

        projekt_phase.budget.investments.includes(:author, comments: :user)
      when ProjektPhase::CommentPhase
        projekt_phase.comments.includes(:user)
      when ProjektPhase::VotingPhase
        sibling = sibling_proposal_phase(projekt_phase)
        return [] if sibling.blank?

        sibling.resources.base_selection.includes(:author, comments: :user)
      else
        []
      end
    end

    def sibling_proposal_phase(projekt_phase)
      projekt_phase
        .projekt
        .projekt_phases
        .where(type: "ProjektPhase::ProposalPhase")
        .first
    end

    def generate_answer(resources)
      items_text =
        resources.map do |item|
          build_item_text(item)
        end.join("\n\n")

      system_instructions = build_system_instructions
      user_prompt = build_user_prompt(items_text, resources)

      response =
        Ai::RubyLlmFactory
          .chat(feature: "ai_analytics.phase_stat_question")
          .with_instructions(Ai::EvaluationContext.prepend_to(system_instructions, projekt_phase))
          .ask(user_prompt)

      response.content.strip
    end

    def build_item_text(item)
      return build_comment_item_text(item) if item.is_a?(Comment)

      text = "Title: #{item.title}"
      text += "\nDescription: #{item.description&.truncate(500)}" if item.description.present?

      if item.respond_to?(:comments) && item.comments.any?
        comments_text = item.comments.first(5).map do |c|
          "- #{c.body&.truncate(100)}"
        end.join("\n")
        text += "\nComments:\n#{comments_text}"
      end

      text
    end

    def build_comment_item_text(comment)
      text = "Comment: #{comment.body&.truncate(500)}"
      text += "\nAuthor: #{comment.user.name}" if comment.user.present?
      text
    end

    def build_system_instructions
      fetched_prompt = fetch_prompt

      <<~TEXT
        #{fetched_prompt}
        Output response in #{target_language} language.
      TEXT
    end

    def build_user_prompt(items_text, resources)
      resource_type = resource_label(resources.first)

      <<~TEXT
        Based on the following #{resource_type}, answer this question:
        #{stat_question.question}

        #{resource_type.capitalize}:
        #{items_text}
      TEXT
    end

    def resource_label(item)
      case item
      when Budget::Investment
        "budget proposals"
      when Comment
        "user comments"
      else
        "proposals"
      end
    end

    def fetch_prompt
      parsed_response =
        DtApi::Client.new(use_cache: true).consul_ai_prompts.get(
          :ai_analytics_projekt_phase_question,
          resource_type: "projekt_phase"
        ).parsed_response
      parsed_response.dig("consul_ai_prompt", "prompt")
    end
end
