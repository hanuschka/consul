load Rails.root.join("app", "models", "progress_bar.rb")

class ProgressBar < ApplicationRecord
  def projekt
    progressable.is_a?(Projekt) ? progressable : nil
  end
end
