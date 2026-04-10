class SeedSectionSettingIntroTexts < ActiveRecord::Migration[6.1]
  def up
    intro_texts = {
      "projekts" => "Hier verwalten Sie Ihre Beteiligungsprojekte. Erstellen Sie neue Projekte, konfigurieren Sie Phasen und Einstellungen, und behalten Sie den Überblick über laufende und abgeschlossene Beteiligungsverfahren.",
      "deficiency_reports" => "Hier verwalten Sie eingehende Mängelmeldungen der Bürgerinnen und Bürger. Weisen Sie Meldungen zu, verfolgen Sie den Bearbeitungsstatus und koordinieren Sie die Behebung gemeldeter Probleme.",
      "ideas" => "Hier verwalten Sie die eingereichten Bürgerideen. Prüfen Sie neue Einreichungen, weisen Sie Ideen Bearbeitern zu und verfolgen Sie den Status von der Einreichung bis zur Umsetzung.",
      "moderation" => "Hier moderieren Sie nutzergenerierte Inhalte der Plattform. Prüfen Sie gemeldete Beiträge, Kommentare und Nutzerkonten, und sorgen Sie für einen respektvollen und konstruktiven Austausch.",
      "valuation" => "Hier bewerten Sie eingereichte Bürgerbudget-Vorschläge. Prüfen Sie die Machbarkeit, schätzen Sie Kosten ein und dokumentieren Sie Ihre Bewertungsergebnisse für die weitere Bearbeitung.",
      "landing_pages" => "Hier verwalten Sie die Themenseiten Ihrer Plattform. Erstellen und bearbeiten Sie Seiten zu bestimmten Themen, veröffentlichen oder verbergen Sie Inhalte und gestalten Sie die Informationsarchitektur."
    }

    intro_texts.each do |section, text|
      setting = SectionSetting.find_or_initialize_by(section: section)
      setting.update!(intro_text: text) if setting.intro_text.blank?
    end
  end

  def down
    SectionSetting.where(section: %w[projekts deficiency_reports ideas moderation valuation landing_pages]).destroy_all
  end
end
