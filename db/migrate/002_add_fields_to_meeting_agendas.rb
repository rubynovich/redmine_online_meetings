class AddFieldsToMeetingAgendas < ActiveRecord::Migration
  def change
    add_column :meeting_agendas, :is_online, :boolean, default:false
    add_column :meeting_agendas, :online_meeting_url, :string
    add_column :meeting_agendas, :online_meeting_uid, :string
  end
end
