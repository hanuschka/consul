# The "Projekt importieren" entry point: one button that asks where the projekt
# comes from before any import screen is opened.
#
# A source whose material the AI has to read is offered but disabled when the AI
# is switched off; the Consul-projekt source never needs it, so it stays usable
# on an instance without one.
class Adm::Projekts::Imports::SourcePickerComponent < ApplicationComponent
  Source = Struct.new(:key, :label, :description, :icon, :url, :needs_ai, keyword_init: true) do
    def available?(ai_available)
      return true if !needs_ai

      ai_available
    end
  end

  def initialize(label:, ai_available:)
    @label = label
    @ai_available = ai_available
  end

  private

    attr_reader :label, :ai_available

    def sources
      [
        Source.new(
          key: "file",
          label: t("adm.projekts.imports.sources.file.label"),
          description: t("adm.projekts.imports.sources.file.description"),
          icon: "upload_file",
          url: helpers.new_adm_projekts_imports_from_file_path,
          needs_ai: true
        ),
        Source.new(
          key: "consul_projekt",
          label: t("adm.projekts.imports.sources.consul_projekt.label"),
          description: t("adm.projekts.imports.sources.consul_projekt.description"),
          icon: "move_down",
          url: helpers.new_adm_projekts_imports_from_consul_projekt_path,
          needs_ai: false
        ),
        Source.new(
          key: "url",
          label: t("adm.projekts.imports.sources.url.label"),
          description: t("adm.projekts.imports.sources.url.description"),
          icon: "language",
          url: helpers.new_adm_projekts_imports_from_url_path,
          needs_ai: true
        )
      ]
    end

    def unavailable_note
      t("adm.projekts.imports.sources.requires_ai")
    end
end
