class ContentCard::ProjektBuckets
  # One shared association set for all three projekt cards, loaded in a single
  # Preloader pass over the union of the buckets instead of once per card.
  PRELOAD_ASSOCIATIONS = [
    :projekt_settings, :tags,
    { page: [:image, :translations] },
    { active_and_visible_projekt_phases: [:translations, :settings] },
    { sdg_relations: :related_sdg }
  ].freeze

  def self.for(custom_page, user)
    Current.content_card_projekt_buckets ||= {}
    memo_key = [custom_page&.id, user&.id]

    Current.content_card_projekt_buckets[memo_key] ||= new(custom_page, user)
  end

  def initialize(custom_page, user)
    @custom_page = custom_page
    @user = user
  end

  def active
    buckets[:active]
  end

  def current
    buckets[:current]
  end

  def expired
    buckets[:expired]
  end

  private

    def buckets
      @buckets ||= load_buckets
    end

    def load_buckets
      visible_projekts = base_projekts.visible_for(@user)

      current_projekts = visible_projekts.sort_by_order_number.index_order_underway.to_a
      expired_projekts = visible_projekts.index_order_expired.sort_by_order_number.to_a

      # The exclusion list only ever filters already-visible candidates, so
      # restricting it to the visible buckets is equivalent to the unfiltered
      # index_order_* id sets the cards used to pluck separately.
      excluded_ids = (current_projekts + expired_projekts).map(&:id).uniq
      active_projekts =
        visible_projekts
          .activated
          .where.not(id: excluded_ids)
          .sort_by_order_number
          .to_a

      ActiveRecord::Associations::Preloader.new.preload(
        active_projekts + current_projekts + expired_projekts, PRELOAD_ASSOCIATIONS
      )

      { active: active_projekts, current: current_projekts, expired: expired_projekts }
    end

    def base_projekts
      if @custom_page.present?
        @custom_page.landing_projekts.show_in_homepage
      else
        ::Projekt.show_in_homepage
      end
    end
end
