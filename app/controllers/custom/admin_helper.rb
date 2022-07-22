require_dependency Rails.root.join("app", "helpers", "admin_helper").to_s

module AdminHelper
  def dashboard_index_back_path
    if controller_name == 'projekts' &&
        action_name == 'edit' &&
        @projekt.present? &&
        @projekt.page.present? &&
        @projekt.page.status == 'published'
      page_path(@projekt.page.slug)

    elsif controller_name == 'pages' &&
        action_name == 'edit' &&
        @page.present? &&
        @page.status == 'published'
      page_path(@page.slug)

    else
      root_path

    end
  end

  # path helpers for projekt questions

  def new_projekt_question_path(projekt_id)
    if params[:controller].include?('projekt_management')
      new_projekt_management_projekt_projekt_question_path(projekt_id: projekt_id)
    else
      new_admin_projekt_projekt_question_path(projekt_id: projekt_id)
    end
  end

  def edit_projekt_question_path(projekt, question)
    if params[:controller].include?('projekt_management')
      edit_projekt_management_projekt_projekt_question_path(projekt, question)
    else
      edit_admin_projekt_projekt_question_path(projekt, question)
    end
  end

  def redirect_to_projekt_questions_path(projekt)
    if params[:controller].include?('projekt_management')
      edit_projekt_management_projekt_path(projekt) + '#tab-projekt-questions'
    else
      edit_admin_projekt_path(projekt) + '#tab-projekt-questions'
    end
  end
end
