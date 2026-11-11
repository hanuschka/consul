require "rails_helper"

describe MachineTranslation::ChromeStore do
  let(:locale) { MachineTranslation.translatable_locales.first }

  def store(key, value)
    content = I18nContent.find_or_create_by!(key: key)
    Globalize.with_locale(locale) { content.update!(value: value) }
    content.translations.find_by!(locale: locale).id
  end

  before { described_class.reset! }
  after { described_class.reset! }

  describe ".stale_translation_ids" do
    it "returns stored translations that use a placeholder the source text no longer has" do
      stale = store("mailers.user_verification_failed.b2_item1", "Relancez votre vérification : %{link}")
      current = store("mailers.reply.text", "Voir la réponse : %{comment_url}")
      shortened = store("mailers.proposal_created.text1", "Votre proposition a été reçue.")

      expect(described_class.stale_translation_ids).to include(stale)
      expect(described_class.stale_translation_ids).not_to include(current, shortened)
    end

    it "checks a plural category the source lacks against the source's other form" do
      source = MachineTranslation::ChromeWriter.corpus(MachineTranslation.source_locale)
      base = source.keys.find do |key|
        key.end_with?(".other") && source[key].is_a?(String) && source[key].include?("%{count}") &&
          !source.key?(key.sub(/other\z/, "few"))
      end.delete_suffix(".other")

      stale = store("#{base}.few", "%{amount} éléments")
      current = store("#{base}.many", "%{count} éléments")

      expect(described_class.stale_translation_ids).to include(stale)
      expect(described_class.stale_translation_ids).not_to include(current)
    end

    it "ignores stored keys that have no source text" do
      orphan = store("custom.spec_no_source_text", "Bonjour %{name}")

      expect(described_class.stale_translation_ids).not_to include(orphan)
    end
  end
end
