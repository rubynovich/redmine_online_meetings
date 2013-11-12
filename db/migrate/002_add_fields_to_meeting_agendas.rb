class AddFieldsToMeetingRooms < ActiveRecord::Migration
  def change
    add_column :meeting_agendas, :is_online, :boolean, default:false
    add_column :meeting_agendas, :online_meeting_url_id, :string


  end
end
