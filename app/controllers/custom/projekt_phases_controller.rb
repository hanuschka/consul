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

  def create_stat_question
    @projekt_phase = ProjektPhase.find(params[:id])
    authorize!(:refresh_stats, @projekt_phase)

    if !Ai::Settings.ai_available?
      respond_to do |format|
        format.json { render json: { error: "AI features unavailable" }, status: :forbidden }
        format.turbo_stream { head :forbidden }
      end

      return
    end

    @stat_question = @projekt_phase.stat_questions.build(
      question: params[:question],
      status: :pending
    )

    if @stat_question.save
      AiAnalytics::StatQuestionRefresh.perform_later(@stat_question.id)

      respond_to do |format|
        format.json do
          render json: {
            id: @stat_question.id,
            status: "pending",
            question: @stat_question.question,
            status_url: stat_question_status_projekt_phase_path(@projekt_phase, question_id: @stat_question.id)
          }
        end
        format.turbo_stream
      end
    else
      respond_to do |format|
        format.json { render json: { error: @stat_question.errors.full_messages.join(", ") }, status: :unprocessable_entity }
        format.turbo_stream { head :unprocessable_entity }
      end
    end
  end

  def stat_question_status
    @projekt_phase = ProjektPhase.find(params[:id])
    @stat_question = @projekt_phase.stat_questions.find(params[:question_id])
    authorize!(:refresh_stats, @projekt_phase)

    respond_to do |format|
      format.json { render json: stat_question_status_json_payload }
      format.turbo_stream
    end
  end

  def download_stat_answer
    @projekt_phase = ProjektPhase.find(params[:id])
    @stat_question = @projekt_phase.stat_questions.find(params[:question_id])
    authorize!(:refresh_stats, @projekt_phase)

    download_format = params[:format] || "txt"
    filename = generate_stat_answer_filename(@projekt_phase, @stat_question, download_format)

    case download_format
    when "pdf"
      pdf = PdfServices::StatQuestionExporter.new(@stat_question).call
      send_data pdf.render,
                filename: filename,
                type: "application/pdf",
                disposition: "attachment"
    else
      send_data generate_stat_answer_text(@stat_question),
                filename: filename,
                type: "text/plain",
                disposition: "attachment"
    end
  end

  def delete_stat_question
    @projekt_phase = ProjektPhase.find(params[:id])
    @stat_question = @projekt_phase.stat_questions.find(params[:question_id])
    authorize!(:refresh_stats, @projekt_phase)

    @stat_question.destroy

    respond_to do |format|
      format.json { render json: { success: true } }
      format.turbo_stream
    end
  end

  def download_all_stat_answers
    @projekt_phase = ProjektPhase.find(params[:id])
    authorize!(:refresh_stats, @projekt_phase)

    download_format = params[:format] || "pdf"
    filename = generate_all_stat_answers_filename(@projekt_phase, download_format)

    case download_format
    when "pdf"
      pdf = PdfServices::AllStatQuestionsExporter.new(@projekt_phase).call
      send_data pdf.render,
                filename: filename,
                type: "application/pdf",
                disposition: "attachment"
    when "docx"
      docx = DocxServices::AllStatQuestionsExporter.new(@projekt_phase).call
      send_data docx,
                filename: filename,
                type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                disposition: "attachment"
    when "odt"
      odt = OdtServices::AllStatQuestionsExporter.new(@projekt_phase).call
      send_data odt,
                filename: filename,
                type: "application/vnd.oasis.opendocument.text",
                disposition: "attachment"
    else
      send_data generate_all_stat_answers_text(@projekt_phase),
                filename: filename,
                type: "text/plain",
                disposition: "attachment"
    end
  end

  private

    def stat_question_status_json_payload
      payload = {
        id: @stat_question.id,
        status: @stat_question.status,
        answer: @stat_question.answer,
        created_at: @stat_question.created_at
      }

      if @stat_question.status == "completed"
        payload[:html] = render_to_string(
          partial: "custom/particapation_stats/completed_question_item",
          locals: { question: @stat_question, projekt_phase: @projekt_phase },
          layout: false
        )
      end

      payload
    end

    def generate_stat_answer_filename(projekt_phase, stat_question, format)
      projekt_name = projekt_phase.projekt.title.parameterize(separator: "-")
      "#{projekt_name}-ai-question-#{stat_question.id}.#{format}"
    end

    def generate_stat_answer_text(stat_question)
      plain_answer = helpers.strip_tags(stat_question.answer.to_s)

      <<~TEXT
        AI Question Analysis
        Date: #{stat_question.created_at.strftime("%d %b %Y %H:%M")}

        Question:
        #{stat_question.question}

        Answer:
        #{plain_answer}
      TEXT
    end

    def generate_all_stat_answers_filename(projekt_phase, format)
      projekt_name = projekt_phase.projekt.title.parameterize(separator: "-")
      phase_name = projekt_phase.title.parameterize(separator: "-")
      "#{projekt_name}-#{phase_name}-ai-questions.#{format}"
    end

    def generate_all_stat_answers_text(projekt_phase)
      stat_questions = projekt_phase.stat_questions.answered.by_newest
      text_parts = [
        "AI Questions Analysis",
        "Project: #{projekt_phase.projekt.title}",
        "Phase: #{projekt_phase.title}",
        "Exported: #{Time.current.strftime('%d %b %Y %H:%M')}",
        "",
        ""
      ]

      stat_questions.each_with_index do |stat_question, index|
        plain_answer = helpers.strip_tags(stat_question.answer.to_s)
        text_parts << "Question #{index + 1}:"
        text_parts << stat_question.question
        text_parts << ""
        text_parts << "Answer:"
        text_parts << plain_answer
        text_parts << ""
        text_parts << "Date: #{stat_question.created_at.strftime('%d %b %Y %H:%M')}"
        text_parts << ""
        text_parts << "-" * 80
        text_parts << ""
      end

      text_parts.join("\n")
    end

end
