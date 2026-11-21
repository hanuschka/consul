module Adm::NewslettersHelper
  def recipient_group_options
    RecipientGroup.with_projekt_titles.map { [it.display_name, it.id] }
  end
end
