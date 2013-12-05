Redmine::Plugin.register :redmine_online_meetings do
  name 'Remine Online Meetings plugin'
  author 'Maksim Koritskiy'
  description 'Redmine plugin for drawing and update data from Gantt diagram'
  version '0.0.1'
  url 'https://bitbucket.org/gorkapstroy/redmine_online_meetings'
  author_url 'http://maksim.koritskiy.ru'
  requires_redmine :version_or_higher => '2.0.3'
  settings :partial => 'online_meetings/settings'
  #project_module :advanced_gantt do
  #  permission :view_advanced_gantt, :advanced_gantt_project => :index
  #end
  #menu :project_menu, :advanced_gantt, { :controller => :advanced_gantt_project, :action => :index }, :caption => :advanced_gantt, :after => :new_issue
end

#require 'concerns/decorators'

#[].each do |decorator|
#  require "decorators/#{decorator}_decorator"
#end

require 'concerns/g_cal4_ruby_patch'
GCal4Ruby::Event.send(:remove_const, :EVENT_XML)
GCal4Ruby::Event.send(:include, GCal4RubyPatch::Event)
GCal4Ruby::Service.send(:include, GCal4RubyPatch::Service)
require 'concerns/online_meeting_agenda_patch'
require 'concerns/online_meeting_mailer_patch'
require 'concerns/issue_patch'
require 'meeting_agendas_controller_patch'

Issue.send(:include, Issue)
Mailer.send(:include, OnlineMeetingMailerPatch)
MeetingAgenda.send(:include, OnlineMeetingAgendaPatch)
MeetingAgendasController.send(:include, OnlineMeetings::MeetingAgendasControllerPatch) unless MeetingAgendasController.included_modules.include? OnlineMeetings::MeetingAgendasControllerPatch

#MeetingAgendasController.send(:include, MeetingAgendasControllerPatch)
#MeetingAgendasControllerPatch
#[].each do |patch|
#  require "patches/#{patch}_patch"
#  class_eval(patch.to_s.camelize).send :include, class_eval("#{patch}_patch".camelize)
#end


