namespace :adm do
  namespace :moderation do
    root to: "users#index"

    resources :users, only: :index do
      member do
        put :hide
        put :block
      end
    end
  end
end
