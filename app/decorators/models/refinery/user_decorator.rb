# Open the Refinery::Page model for manipulation
Refinery::User.class_eval do
  attr_accessible :userid_detail_id

  def userid_detail
    UseridDetail.find(self.userid_detail_id)
  end
end