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
    stat_question.update!(status: :completed, answer: answer)

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
        return [] unless projekt_phase.budget

        projekt_phase.budget.investments.includes(:author, comments: :user)
      else
        []
      end
    end

    def generate_answer(resources)
      items_text =
        resources.map { |item|
          build_item_text(item)
        }.join("\n\n")

      prompt = build_prompt(items_text, resources)

      # sleep 15
      # "test content"

      response = Ai::RubyLlmFactory.chat.ask(prompt)
      response.content.strip
    end

    def build_item_text(item)
      text = "Title: #{item.title}"
      text += "\nDescription: #{item.description&.truncate(500)}" if item.description.present?

      if item.respond_to?(:comments) && item.comments.any?
        comments_text = item.comments.first(5).map { |c|
          "- #{c.body&.truncate(100)}"
        }.join("\n")
        text += "\nComments:\n#{comments_text}"
      end

      text
    end

    def build_prompt(items_text, resources)
      resource_type = resources.first.is_a?(Budget::Investment) ? "budget proposals" : "proposals"
      projekt_title = projekt_phase.projekt.page.title
      projekt_subtitle = projekt_phase.projekt.page.subtitle

      <<~TEXT
        You are an assistant helping project managers analyze citizen participation #{resource_type} in #{projekt_title} with subtitle #{projekt_subtitle}

        Based on the following #{resource_type}, answer this question:
        #{stat_question.question}

        #{resource_type.capitalize}:
        #{items_text}

        Instructions:
        - Provide a comprehensive, factual answer in #{target_language}
        - Base your answer only on the provided #{resource_type}
        - If the question cannot be answered from the #{resource_type}, clearly state that
        - Be specific and reference relevant #{resource_type} when applicable
        - Structure your answer clearly with paragraphs if needed
        - Use html formating with h2 and p tags
        - Dont use br html tags
        - Dont be too verbose
      TEXT
    end
end
