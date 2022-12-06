require_dependency Rails.root.join("app", "components", "application_component").to_s

class ApplicationComponent < ViewComponent::Base
  delegate :current_path_with_query_params, to: :helpers

  def set_comment_flags(comments)
    @comment_flags = helpers.current_user ? helpers.current_user.comment_flags(comments) : {}
    @comment_flags
  end
end
