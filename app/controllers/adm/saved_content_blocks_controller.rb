class Adm::SavedContentBlocksController < Adm::BaseController
  include SavedContentBlockAdminActions

  before_action :authorize_saved_content_block

  private

    def authorize_saved_content_block
      authorize @saved_content_block || SavedContentBlock,
                policy_class: Adm::SavedContentBlockPolicy
    end
end
