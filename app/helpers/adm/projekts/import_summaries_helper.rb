module Adm::Projekts::ImportSummariesHelper
  IMPORT_SUMMARY_DATE_FORMAT = "%d.%m.%Y".freeze

  # A period the AI left half-open still says something useful, so one missing
  # end renders as the single date it does know rather than as "not set".
  def import_summary_period(starts_on, ends_on)
    dates = [starts_on, ends_on].compact

    if dates.empty?
      return tag.span(t("adm.projekts.imports.summary.none"),
                      class: "projekt-import-summary--empty")
    end

    dates.map { |date| date.strftime(IMPORT_SUMMARY_DATE_FORMAT) }.join(" – ")
  end
end
