module Adm::NewslettersHelper
  def newsletter_recipient_target_options
    group_options = RecipientGroup.order(:name).pluck(:name, :id).map do |name, id|
      [name, "group:#{id}"]
    end

    projekt_options = Projekt.joins(:subscriptions).distinct.order(:name).pluck(:name, :id).map do |name, id|
      [t("adm.newsletters.recipient_target.projekt_subscribers", projekt: name), "projekt:#{id}"]
    end

    group_options + projekt_options
  end
end
