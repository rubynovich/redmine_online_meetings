class AddServerIdToMeetingAgendas < ActiveRecord::Migration
  def change
    add_column :meeting_agendas, :server_id, :integer
  end
end
