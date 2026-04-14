class Adm::CommentPolicy < ApplicationPolicy
  include Adm::Projekts::PermissionCheck

  def hide?
    can_moderate_projekt?
  end

  def unhide?
    can_moderate_projekt? && @record.hidden?
  end

  def ignore_flag?
    can_moderate_projekt? && !@record.ignored_flag? && !@record.hidden?
  end

  private

    def projekt_from_record
      if @record.commentable.respond_to?(:projekt)
        @record.commentable.projekt
      elsif @record.commentable.is_a?(ProjektPhase)
        @record.commentable.projekt
      end
    end

    def can_moderate_projekt?
      @user&.has_pm_permission_to?("moderate", projekt_from_record)
    end
end
