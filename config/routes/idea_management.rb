namespace :idea_management do
  root to: "ideas#index"

  resources :ideas, except: [:new, :create] do
    resources :audits, only: :show, controller: "idea_audits"
    resources :milestones, controller: "idea_milestones"
    resources :progress_bars, except: :show, controller: "idea_progress_bars"
    member do
      get :audits
      patch :accept
      patch :toggle_image
    end
  end

  resources :officers, only: [:index, :create, :destroy] do
    get :search, on: :collection
  end

  resources :categories, only: %i[index new create edit update destroy] do
    collection do
      post "order_categories"
    end
  end

  resources :memos, only: %i[create] do
    member do
      post :send_notification
    end
  end

  resources :settings, only: :index
  resources :districts, only: [:index, :edit, :update]
end
