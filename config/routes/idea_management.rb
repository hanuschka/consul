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

  resources :settings, only: :index
end
