# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html
#resources :meeting_agendas do
#  member do
get 'meeting_agendas/:id/issue' => 'meeting_agendas#issue'
get 'meeting_agendas/:id/start_record' => 'meeting_agendas#start_record'
get 'meeting_agendas/:id/stop_record' => 'meeting_agendas#stop_record'
post 'meeting_agendas/:id/continue_record' => 'meeting_agendas#continue_record'
#  end
#end