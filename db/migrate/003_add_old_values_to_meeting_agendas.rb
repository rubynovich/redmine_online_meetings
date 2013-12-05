class AddFieldsToMeetingAgendas < ActiveRecord::Migration
  def change
    add_column :meeting_agendas, :old_start_time, :datetime
    add_column :meeting_agendas, :old_place, :string
    add_column :meeting_agendas, :old_address, :string
  end
end
