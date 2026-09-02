class Tags::ToggleSelectionService < ApplicationService
  def initialize(selected_tags_param, toggled_tag_name)
    @selected_tags_param = selected_tags_param
    @toggled_tag_name = toggled_tag_name
  end

  def call
    tag_names = selected_tag_names

    if tag_names.include?(@toggled_tag_name)
      tag_names -= [ @toggled_tag_name ]
    else
      tag_names += [ @toggled_tag_name ]
    end

    tag_names.join(",")
  end

  private

    def selected_tag_names
      return [] if @selected_tags_param.blank?

      @selected_tags_param.split(",")
    end
end
