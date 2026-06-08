class Adm::CommentPolicy < ApplicationPolicy
  include Adm::Projekts::PermissionCheck

  def hide?
    moderate_permitted?
  end

  def unhide?
    moderate_permitted? && @record.hidden?
  end

  def ignore_flag?
    moderate_permitted? && !@record.ignored_flag? && !@record.hidden?
  end

  private

    def projekt_from_record
      if @record.commentable.respond_to?(:projekt)
        @record.commentable.projekt
      elsif @record.commentable.is_a?(ProjektPhase)
        @record.commentable.projekt
      end
    end
end
