module LanguageDetector
  GERMAN_MARKERS = %w[
    der die das und ist ich nicht ein eine mit auch auf für sich
    dem den des werden wird sind haben oder aber zur zum straße
    können möglichkeiten wurde durch sowie sollen
  ].freeze

  ENGLISH_MARKERS = %w[
    the and is are was of to in for on with that this it as be
    by an or but not have has will from at which their they you
  ].freeze

  def self.detect(text)
    sample = text.to_s.downcase
    return nil if sample.blank?

    german = count_markers(sample, GERMAN_MARKERS)
    english = count_markers(sample, ENGLISH_MARKERS)

    return nil if german.zero? && english.zero?
    return :de if german > english
    return :en if english > german

    nil
  end

  def self.count_markers(sample, markers)
    markers.sum do |word|
      sample.scan(/(?<![[:alpha:]])#{Regexp.escape(word)}(?![[:alpha:]])/).size
    end
  end
end
