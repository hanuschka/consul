class Tags::ExistingNamesService < ApplicationService
  def initialize(tags_param)
    @tags_param = tags_param
  end

  def call
    return [] if requested_tag_names.blank?

    requested_tag_names & ::Tag.where(name: requested_tag_names).pluck(:name)
  end

  private

    def requested_tag_names
      @requested_tag_names ||=
        @tags_param.present? ? @tags_param.split(",") : []
    end
end
