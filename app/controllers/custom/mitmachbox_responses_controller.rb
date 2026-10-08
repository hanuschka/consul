class MitmachboxResponsesController < ApplicationController
  include GuestUsers

  skip_authorization_check only: :create

  def create
    @projekt_phase = ProjektPhase.find(params[:id])
    unless @projekt_phase.is_a?(ProjektPhase::MitmachboxPhase)
      return redirect_back(fallback_location: root_path)
    end

    unless @projekt_phase.online_answering_open?
      return redirect_to(footer_path, alert: mitmachbox_t("closed"))
    end

    establish_guest_session! if current_user.blank?

    survey = Mitmachbox::PublicSurveyService.call(@projekt_phase)

    if survey.blank? || survey["state"] != "open"
      return redirect_to(footer_path, alert: mitmachbox_t("closed"))
    end

    if @projekt_phase.answered_by?(current_user, survey["version_id"])
      return redirect_to(footer_path, notice: mitmachbox_t("already_answered"))
    end

    path = Mitmachbox::SurveyPath.new(survey["questions"])
    answers = path.on_path(submitted_answers(survey))

    if missing_required_questions(survey, answers, path).any?
      return redirect_to(footer_path, alert: mitmachbox_t("missing_required"))
    end

    if answers.empty?
      return redirect_to(footer_path, alert: mitmachbox_t("no_answers"))
    end

    Mitmachbox::SubmitWebResponseService.call(
      projekt_phase: @projekt_phase,
      user: current_user,
      survey_version_id: survey["version_id"],
      answers: answers
    )

    redirect_to footer_path, notice: mitmachbox_t("thank_you")
  rescue Mitmachbox::Error
    Mitmachbox::PublicSurveyService.expire!(@projekt_phase.mitmachbox_survey_id)
    redirect_to footer_path, alert: mitmachbox_t("submit_failed")
  end

  private

    def establish_guest_session!
      guest_key = "guest_#{SecureRandom.uuid}"
      guest = initialize_guest_user(guest_key)
      return unless guest.save

      session[:guest_user_id] = guest_key
      @guest_user = guest
    end

    def footer_path
      page_path(@projekt_phase.projekt.page.slug,
        projekt_phase_id: @projekt_phase.id, anchor: "projekt-footer")
    end

    def mitmachbox_t(key)
      t("custom.projekt_phases.mitmachbox_phase.#{key}")
    end

    def submitted_answers(survey)
      submitted = params[:mitmachbox_answers]
      return [] unless submitted.respond_to?(:each_pair)

      survey["questions"].flat_map do |question|
        valid_ids = question["options"].map { |option| option["id"] }
        option_ids = scalar_ids(submitted[question["id"].to_s]) & valid_ids
        option_ids = option_ids.first(1) unless question["question_type"] == "multiple_choice"

        option_ids.map { |option_id| { question_id: question["id"], option_id: option_id } }
      end
    end

    def scalar_ids(value)
      Array(value)
        .select { |entry| entry.is_a?(String) || entry.is_a?(Integer) }
        .reject(&:blank?)
        .map(&:to_i)
    end

    # A required question the run never reached cannot be missing: branching
    # routes past it, exactly as it does on the box.
    def missing_required_questions(survey, answers, path)
      answered = answers.map { |answer| answer[:question_id] }.uniq
      chosen = answers.group_by { |answer| answer[:question_id] }
                      .transform_values { |group| group.map { |answer| answer[:option_id] } }
      reached = path.reached_question_ids(chosen)

      survey["questions"].select do |question|
        question["required"] && reached.include?(question["id"]) &&
          answered.exclude?(question["id"])
      end
    end
end
