class CreateOnlineMeetingRooms < ActiveRecord::Migration
  def change
    create_table :online_meeting_rooms do |t|
      t.references :meeting_room
      t.string :account
      t.string :password
      t.datetime :start_time
      t.datetime :end_time
      t.boolean :is_recording, default: false
      t.string :vm_uid
    end
  end
end
