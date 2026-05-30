Rails.application.routes.draw do
  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?

  devise_for :users
  root "static_pages#top"

  resources :items, only: %i[index new create show edit update destroy] do
    member do
      patch :start_using
      get :finish_using_form, path: :finish_using
      patch :finish_using
      delete :image, action: :destroy_image
    end

    collection do
      get :used_up
      get :in_use
    end
  end

  resources :usage_logs, only: %i[edit update] do
    collection do
      get :reviews
    end
  end
end
