class MachineTranslation::ChromeWriter
  MAX_COUNT_PROBE = 200

  attr_reader :locale, :limit

  def initialize(locale, limit: nil)
    @locale = locale.to_sym
    @limit = limit
  end

  def pending_entries
    entries = source_corpus.filter_map do |key, value|
      next unless MachineTranslation.translatable_key?(key)
      next unless MachineTranslation.translatable_value?(value)
      next if already_translated?(key)

      { key: key, source: value, html: html_key?(key) }
    end

    entries += missing_plural_entries
    entries = entries.first(limit) if limit

    entries
  end

  def mode_for(entry)
    MachineTranslation::TextMode.mode_for(entry[:source], html: entry[:html])
  end

  def call
    entries = pending_entries
    return empty_result if entries.empty?

    written = 0
    rejected = []

    entries.group_by { |entry| mode_for(entry) }.each do |mode, group|
      translated = translate(group.map { |entry| entry[:source] }, mode)

      group.each_with_index do |entry, index|
        output = accept(entry, translated[index], mode) || retry_entry(entry, mode)

        if output.blank?
          rejected << entry[:key]
          next
        end

        store(entry[:key], output)
        written += 1
      end
    end

    { written: written, rejected: rejected, characters: entries.sum { |e| e[:source].length } }
  end

  def target_plural_categories
    (0..MAX_COUNT_PROBE).map { |count| MachineTranslation.plural_category(locale, count) }.uniq
  end

  private

    def empty_result
      { written: 0, rejected: [], characters: 0 }
    end

    def accept(entry, raw, mode)
      return if raw.blank?

      value = MachineTranslation::TextMode.restore(raw, mode)

      value if MachineTranslation.placeholders_intact?(entry[:source], value)
    end

    def retry_entry(entry, mode)
      fallback = MachineTranslation::TextMode.fallback_for(mode)
      return if fallback.nil?

      accept(entry, translate([entry[:source]], fallback).first, fallback)
    end

    def translate(texts, mode)
      prepared = texts.map { |text| MachineTranslation::TextMode.prepare(text, mode) }

      send_texts(prepared, mode)
    rescue Deepl::Error
      prepared.map do |text|
        begin
          send_texts([text], mode).first
        rescue Deepl::Error
          nil
        end
      end
    end

    def send_texts(texts, mode)
      Deepl::Client.new.translate(texts,
                                  target_locale: locale,
                                  source_locale: MachineTranslation.source_locale,
                                  **MachineTranslation::TextMode.options(mode))
    end

    def store(key, value)
      MachineTranslation.store_content(key, value, locale)
    end

    def missing_plural_entries
      plural_bases.filter_map do |base|
        fallback = source_corpus["#{base}.other"]
        next if fallback.blank?

        target_plural_categories.filter_map do |category|
          key = "#{base}.#{category}"
          next if source_corpus.key?(key)
          next if already_translated?(key)

          { key: key, source: fallback, html: html_key?(key) }
        end
      end.flatten
    end

    def plural_bases
      @plural_bases ||= source_corpus.keys.filter_map { |key|
        segments = key.split(".")
        base = segments[0..-2].join(".")

        base if MachineTranslation::PLURAL_CATEGORIES.include?(segments.last.to_sym) &&
                MachineTranslation.translatable_key?(base)
      }.uniq
    end

    def already_translated?(key)
      target_corpus.key?(key) || stored_keys.include?(key)
    end

    def stored_keys
      @stored_keys ||= MachineTranslation::ChromeStore.values(locale).keys.to_set
    end

    def source_corpus
      @source_corpus ||= self.class.corpus(MachineTranslation.source_locale)
    end

    def target_corpus
      @target_corpus ||= self.class.corpus(locale)
    end

    def html_key?(key)
      key.match?(/_html(\.|\z)/)
    end

    class << self
      def corpus(locale)
        backend = I18n.backend
        backend.send(:init_translations) unless backend.initialized?

        flatten(backend.send(:translations)[locale.to_sym] || {})
      end

      def flatten(node, prefix = [], out = {})
        node.each do |key, value|
          path = prefix + [key]

          if value.is_a?(Hash)
            flatten(value, path, out)
          else
            out[path.join(".")] = value
          end
        end

        out
      end
    end
end
