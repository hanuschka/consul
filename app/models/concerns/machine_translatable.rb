module MachineTranslatable
  extend ActiveSupport::Concern

  included do
    translation_class.after_commit(on: [:create, :update]) do
      MachineTranslation::Enqueuer.new(self).call
    end
  end
end
