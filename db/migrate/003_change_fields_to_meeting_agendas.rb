class ChangeFieldsToMeetingAgendas < ActiveRecord::Migration
  def change
    add_column :meeting_agendas, :is_recording, :boolean, default:false
    add_column :meeting_agendas, :record_video_id, :integer
    drop_table :online_meeting_rooms
  end
end
