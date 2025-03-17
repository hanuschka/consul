class Admin::HomepageController < Admin::BaseController
  def show
    load_header
    load_feeds
    load_recommendations
    load_cards
  end

  private

    def load_header
      @header = [::Widget::Card.find_or_create_by(
        title: "header_large", header: true)
      ]
    end

    def load_recommendations
      @recommendations = Setting.find_by(key: "feature.user.recommendations")
    end

    def load_cards
      @cards = ::Widget::Card.body
    end

    def load_feeds
      @feeds = Widget::Feed.order("created_at")
    end
end
