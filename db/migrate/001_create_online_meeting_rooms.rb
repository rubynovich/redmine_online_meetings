class CreateOnlineMeetingRooms < ActiveRecord::Migration
  def change
    create_table :online_meeting_rooms do |t|
      t.references :meeting_room
      t.string :account
      t.string :password
      t.datetime :start_time
      t.datetime :end_time
      t.boolean :recording_now, default: false
      t.string :vm_id
    end
  end
end
