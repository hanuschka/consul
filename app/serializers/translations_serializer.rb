# Every language of a Globalize record as { "de" => { "title" => "…" }, … },
# the same shape clients send back. Reads the loaded translations, so callers
# serializing a list preload them.
class TranslationsSerializer
  def initialize(record, attribute_names)
    @record = record
    @attribute_names = attribute_names.map(&:to_s)
  end

  def serialize
    record.translations.sort_by { it.locale.to_s }.to_h do |translation|
      [translation.locale.to_s, attribute_names.index_with { translation[it] }]
    end
  end

  private

    attr_reader :record, :attribute_names
end
