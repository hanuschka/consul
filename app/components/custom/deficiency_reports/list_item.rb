class DeficiencyReports::ListItem < ApplicationComponent
  attr_reader :deficiency_report

  def initialize(deficiency_report:, wide: false)
    @deficiency_report = deficiency_report
    @wide = wide
  end

  def component_attributes
    {
      resource: @deficiency_report,
      head_title: @deficiency_report.category.name,
      title: deficiency_report.title,
      description: deficiency_report.summary,
      tags: deficiency_report.tags.first(3),
      # sdgs: deficiency_report.related_sdgs.first(5),
      # start_date: deficiency_report.total_duration_start,
      # end_date: deficiency_report.total_duration_end,
      wide: @wide,
      url: helpers.deficiency_report_path(deficiency_report),
      image_url: deficiency_report.image&.variant(:medium),
      date: deficiency_report.created_at,
      author: deficiency_report.author,
      image_placeholder_icon_class: "fa-exclamation-triangle",
      id: deficiency_report.id
    }
  end
end
