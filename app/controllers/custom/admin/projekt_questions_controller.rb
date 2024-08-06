class Admin::ProjektQuestionsController < Admin::BaseController
  include ProjektQuestionAdminActions
  include EmbeddedAuth
end
