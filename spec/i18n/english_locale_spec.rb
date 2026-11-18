require "rails_helper"

describe "English locale files" do
  german_words = %w[
    und oder nicht mit für Sie Ihr Ihre bitte wird werden sind ist einen eine einem zum zur auf bei
    Weiter Zurück Vorschlag Vorschläge Kommentar Kommentare Diskussionen Erster Erste sagte Seite
    Übersicht aktivieren Abstimmung
  ]
  german = /(?<![[:alpha:]])(?:#{german_words.join("|")})(?![[:alpha:]])/

  def english_values(node, key, &block)
    case node
    when Hash then node.each { |child, value| english_values(value, "#{key}.#{child}", &block) }
    when Array then node.each { |value| english_values(value, key, &block) }
    when String then yield key, node
    end
  end

  it "contain no German text" do
    offenders = Rails.root.glob("config/locales/**/*.yml").sort.flat_map do |file|
      data = YAML.load_file(file, aliases: true, permitted_classes: [Symbol])
      next [] unless data.is_a?(Hash) && data.key?("en")

      found = []
      english_values(data["en"], "en") do |key, value|
        found << "#{file.relative_path_from(Rails.root)} #{key}: #{value}" if value.match?(german)
      end
      found
    end

    expect(offenders).to be_empty, "German text in English locale files:\n#{offenders.join("\n")}"
  end
end
