module Adm::SectionVisibility
  SECTION_POLICIES = {
    "administration"     => [Adm::HomePolicy,                                :show?],
    "projekts"           => [Adm::Projekts::ProjektPolicy,                   :index?],
    "landing_pages"      => [Adm::LandingPages::LandingPagePolicy,           :index?],
    "moderation"         => [Adm::Moderation::ProposalPolicy,                :index?],
    "deficiency_reports" => [Adm::DeficiencyReports::DeficiencyReportPolicy, :index?],
    "ideas"              => [Adm::Ideas::IdeaPolicy,                         :index?],
    "valuation"          => [Adm::Valuation::BudgetInvestmentPolicy,         :index?],
    "officing"           => [Adm::Officing::BasePolicy,                      :index?]
  }.freeze

  def self.visible_keys_for(user)
    SECTION_POLICIES.select { |_key, (policy, method)| policy.new(user, nil).public_send(method) }.keys
  end
end
