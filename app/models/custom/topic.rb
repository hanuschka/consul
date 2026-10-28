load Rails.root.join("app", "models", "topic.rb")

class Topic < ApplicationRecord
  include Notifiable

  def comments_allowed?(user)
    true
  end

  def on_behalf_of
    nil
  end

  def author_name
    author.name
  end
end
