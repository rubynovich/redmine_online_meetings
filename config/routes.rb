# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html
resources :meeting_agendas do
  member do
    get 'issue'
    get 'start_record'
    get 'stop_record'
  end
end