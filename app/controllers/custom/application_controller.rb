require_dependency Rails.root.join("app", "controllers", "application_controller").to_s


class ApplicationController < ActionController::Base
  def ensure_project_tag
    @selected_tags = params[:tags]&.split(",")&.map {|tt| t2 = Tag.find_by(name: tt)}&.compact || []
    @project_tag = @selected_tags&.map {|tt| tt&.kind == 'project' ? tt : nil}.compact.first
    @projects = ActsAsTaggableOn::Tag.project
    unless @project_tag
      @project_tag = ActsAsTaggableOn::Tag.general_project
      url_tags = params[:tags]&.split(",") || []
      url_tags << ActsAsTaggableOn::Tag.general_project.name
      prms = params.to_unsafe_h
      prms[:tags] = url_tags.join(",")
      redirect_to(prms) and return
    end
  end
end
