Rails.application.routes.draw do
  devise_for :users
  root "static_pages#top"

  resources :items, only: %i[index new create show edit update destroy] do
    collection do
      get :used_up
      get :in_use
    end
  end
end
