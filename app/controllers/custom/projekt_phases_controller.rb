class ProjektPhasesController < ApplicationController
  # include CustomHelper
  # include ProposalsHelper
  # include ProjektControllerHelper

  skip_authorization_check only: [:map_html]

  def toggle_subscription
    @projekt_phase = ProjektPhase.find(params[:id])
    authorize! :toggle_subscription, @projekt_phase

    redirect_to new_user_session_path and return unless current_user

    if @projekt_phase.subscribed?(current_user)
      @projekt_phase.unsubscribe(current_user)
    else
      @projekt_phase.subscribe(current_user)
    end
  end

  def map_html
    @projekt_phase = ProjektPhase.find(params[:id])
    @projekt = @projekt_phase.projekt
  end

  def refresh_stats
    @projekt_phase = ProjektPhase.find(params[:id])
    authorize!(:refresh_stats, @projekt_phase)

    @projekt_phase.stats_version&.destroy!

    redirect_to page_path(@projekt_phase.projekt.page.slug,
                          projekt_phase_id: @projekt_phase.id,
                          section: "stats")
  end

  def refresh_ai_stats
    @projekt_phase = ProjektPhase.find(params[:id])
    authorize!(:refresh_stats, @projekt_phase)

    # sleep 10
    @projekt_phase.generate_ai_stats

    respond_to do |format|
      format.html do
        redirect_to page_path(@projekt_phase.projekt.page.slug,
                              projekt_phase_id: @projekt_phase.id,
                              section: "stats")
      end
      format.js { head :ok }
    end
  end

  def stats
    @projekt_phase = ProjektPhase.find(params[:id])
    authorize!(:read_stats, @projekt_phase)

    case @projekt_phase
    when ProjektPhase::ProposalPhase
      @stats = ProjektPhase::ProposalPhase::Stats.new(@projekt_phase)
    when ProjektPhase::BudgetPhase
      @budget = @projekt_phase.budget
      @stats = Budget::Stats.new(@budget) if @budget
    end

    @projekt = @projekt_phase.projekt
  end

  def create_stat_question
    @projekt_phase = ProjektPhase.find(params[:id])
    authorize!(:refresh_stats, @projekt_phase)

    @stat_question = @projekt_phase.stat_questions.build(
      question: params[:question],
      status: :pending
    )

    if @stat_question.save
      StatQuestionJob.perform_later(@stat_question.id)
      render json: {
        id: @stat_question.id,
        status: "pending",
        question: @stat_question.question,
        status_url: stat_question_status_projekt_phase_path(@projekt_phase, question_id: @stat_question.id)
      }
    else
      render json: { error: @stat_question.errors.full_messages.join(", ") }, status: :unprocessable_entity
    end
  end

  def stat_question_status
    @projekt_phase = ProjektPhase.find(params[:id])
    @stat_question = @projekt_phase.stat_questions.find(params[:question_id])
    authorize!(:refresh_stats, @projekt_phase)

    render json: {
      id: @stat_question.id,
      status: @stat_question.status,
      answer: @stat_question.answer,
      created_at: @stat_question.created_at
    }
  end

  def download_stat_answer
    @projekt_phase = ProjektPhase.find(params[:id])
    @stat_question = @projekt_phase.stat_questions.find(params[:question_id])
    authorize!(:refresh_stats, @projekt_phase)

    download_format = params[:format] || "txt"

    case download_format
    when "pdf"
      pdf = PdfServices::StatQuestionExporter.new(@stat_question).call
      send_data pdf.render,
                filename: "stat_answer_#{@stat_question.id}.pdf",
                type: "application/pdf",
                disposition: "attachment"
    else
      send_data generate_stat_answer_text(@stat_question),
                filename: "stat_answer_#{@stat_question.id}.txt",
                type: "text/plain",
                disposition: "attachment"
    end
  end

  private

    def generate_stat_answer_text(stat_question)
      <<~TEXT
        AI Question Analysis
        Date: #{stat_question.created_at.strftime("%d %b %Y %H:%M")}

        Question:
        #{stat_question.question}

        Answer:
        #{stat_question.answer}
      TEXT
    end
end
