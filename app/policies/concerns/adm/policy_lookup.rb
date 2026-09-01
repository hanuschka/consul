module Adm::PolicyLookup
  POLICY_CLASS_NAMES = {
    "Setting" => "Adm::SettingPolicy",
    "Projekt" => "Adm::Projekts::ProjektPolicy",
    "ProjektSetting" => "Adm::Projekts::ProjektSettingPolicy",
    "ProjektPhase" => "Adm::Projekts::ProjektPhasePolicy",
    "ProjektPhaseSetting" => "Adm::Projekts::ProjektPhasePolicy",
    "ProjektManager" => "Adm::Projekts::ProjektManagerPolicy",
    "Idea" => "Adm::Ideas::IdeaPolicy",
    "DeficiencyReport" => "Adm::DeficiencyReports::DeficiencyReportPolicy",
    "Proposal" => "Adm::ProposalPolicy",
    "Poll" => "Adm::Projekts::PollPolicy",
    "Poll::Question" => "Adm::Projekts::PollQuestionPolicy",
    "Budget" => "Adm::Projekts::BudgetPolicy",
    "Budget::Phase" => "Adm::Projekts::BudgetPolicy",
    "Budget::Investment" => "Adm::Projekts::BudgetPolicy",
    "Budget::Heading" => "Adm::Projekts::BudgetPolicy",
    "ExternalApiKey" => "Adm::ExternalApiKeyPolicy",
    "ApiClient" => "Adm::ApiClientPolicy",
    "ApiRequestLog" => "Adm::ApiRequestLogPolicy",
    "SiteCustomization::EmailTemplate" => "Adm::SiteCustomization::EmailTemplatePolicy",
    "SiteCustomization::Page" => "Adm::SiteCustomization::PagePolicy",
    "SiteCustomization::Image" => "Adm::SiteCustomization::ImagePolicy",
    "SiteCustomization::Video" => "Adm::SiteCustomization::VideoPolicy",
    "SiteCustomization::ContentBlock" => "Adm::SiteCustomization::ContentBlockPolicy",
    "Newsletter" => "Adm::NewsletterPolicy",
    "Image" => "Adm::ImagePolicy",
    "Document" => "Adm::DocumentPolicy",
    "AdminAsset" => "Adm::AdminAssetPolicy",
    "AdminImage" => "Adm::AdminImagePolicy"
  }.freeze

  class << self
    def policy_class_for(record)
      name = record_class_name(record)

      policy_class_name = POLICY_CLASS_NAMES[name]
      raise ArgumentError, "No policy class defined for #{name}" if policy_class_name.nil?

      policy_class_name.constantize
    end

    def policy_class_if_known(record)
      POLICY_CLASS_NAMES[record_class_name(record)]&.constantize
    end

    private

      def record_class_name(record)
        record_class = record.is_a?(Class) ? record : record.class.base_class
        record_class.name
      end
  end

  private

    def policy_class_for(record)
      Adm::PolicyLookup.policy_class_for(record)
    end
end
