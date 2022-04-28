class Pages::CommentsFormComponent < ApplicationComponent
  delegate :current_user, :user_signed_in?, to: :helpers

  def initialize(projekt)
    @projekt = projekt
  end

  def comments_allowed?
    user_signed_in? &&
      @projekt.present? &&
      @projekt.comments_allowed?(current_user)
  end
end
