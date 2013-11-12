class OnlineMeetingRoom < ActiveRecord::Base
  unloadable
  has_one :meeting_room
  scope :virtual, where(meeting_room_id:nil)
end
