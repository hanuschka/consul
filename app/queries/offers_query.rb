class OffersQuery < ApplicationQuery
  SEARCHABLE_TRANSLATIONS = %w[title short_description times costs registration].freeze
  MAX_SEARCH_WORDS = 10

  def initialize(base_scope, params = {})
    @base_scope = base_scope
    @params = params
  end

  def call
    base_scope
      .then { |r| apply_keywords(r) }
      .then { |r| apply_categories(r) }
  end

  private

    attr_reader :base_scope, :params

    def apply_keywords(scope)
      search_words.reduce(scope) do |result, word|
        pattern = like_pattern(word)
        result.where(id: matching_translations(word)).or(result.where(id: matching_offers(pattern)))
      end
    end

    def matching_translations(word)
      table = Offer.translation_class.arel_table
      conditions = SEARCHABLE_TRANSLATIONS.map { |column| table[column].matches(like_pattern(word)) }
      encoded = HTMLEntities.new.encode(word, :basic, :named)
      conditions << table[:short_description].matches(like_pattern(encoded)) if encoded != word
      Offer.translation_class.where(conditions.reduce(:or)).select(:offer_id)
    end

    def like_pattern(word)
      "%#{escape_like(word)}%"
    end

    def matching_offers(pattern)
      table = Offer.arel_table
      Offer.left_joins(:provider)
           .where(table[:address].matches(pattern).or(Offer::Provider.arel_table[:name].matches(pattern)))
           .select(:id)
    end

    def search_words
      params[:search].to_s.split.uniq.first(MAX_SEARCH_WORDS)
    end

    def apply_categories(scope)
      Offer::Category::KINDS.reduce(scope) do |result, kind|
        ids = Array(params[kind.to_sym]).map(&:to_i).select(&:positive?)
        next result if ids.empty?

        result.where(id: Offer::CategoryAssignment.where(offer_category_id: ids).select(:offer_id))
      end
    end
end
