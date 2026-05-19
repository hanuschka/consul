class ProjektEvaluations::GenerateAiProjectSummary < ApplicationService
  def initialize(projekt, stats)
    @projekt = projekt
    @stats = stats
  end

  def call
    prompt = build_prompt
    response = AiAnalytics::ProjektPhaseSummary.send_to_ai(prompt)

    response
  end

  private

  def build_prompt
    phases_summary = @stats[:phases].map do |phase|
      phase_stats = phase[:stats] || {}
      "- #{phase[:phase_title]} (#{phase[:phase_type].demodulize}): " \
        "#{format_phase_stats(phase_stats)}"
    end.join("\n")

    <<~PROMPT
      Erstelle eine kurze Zusammenfassung (3-5 Sätze) des folgenden Beteiligungsprojekts.
      Beschreibe die Ziele, den Umfang der Beteiligung und die wichtigsten Ergebnisse.

      Projektname: #{@projekt.name}
      Beschreibung: #{@projekt.description.to_s.truncate(500)}
      Laufzeit: #{@projekt.total_duration_start} bis #{@projekt.total_duration_end}

      Gesamtstatistik:
      - #{@stats[:totals][:total_participants]} Teilnehmende
      - #{@stats[:totals][:total_contributions]} Beiträge
      - #{@stats[:totals][:total_supports]} Unterstützungen
      - #{@stats[:totals][:phases_count]} Beteiligungsphasen

      Phasen:
      #{phases_summary}
    PROMPT
  end

  def format_phase_stats(stats)
    parts = []
    parts << "#{stats[:proposals_count]} Vorschläge" if stats[:proposals_count]
    parts << "#{stats[:investments_count]} Investitionen" if stats[:investments_count]
    parts << "#{stats[:participants_count]} Teilnehmende" if stats[:participants_count]
    parts << "#{stats[:comments_count]} Kommentare" if stats[:comments_count]
    parts << "#{stats[:supports_count]} Unterstützungen" if stats[:supports_count]

    parts.join(", ")
  end
end
