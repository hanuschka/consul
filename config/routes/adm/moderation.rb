namespace :adm do
  namespace :moderation do
    root to: "home#show"

    resources :users, only: :index do
      member do
        put :hide
        put :block
      end
    end

    resources :proposals, only: :index do
      member do
        put :hide
        put :ignore_flag
      end
    end

    resources :budget_investments, only: :index do
      member do
        put :hide
        put :unhide
        put :ignore_flag
      end
    end

    resources :comments, only: :index do
      member do
        put :hide
        put :unhide
        put :ignore_flag
      end
    end
  end
end
