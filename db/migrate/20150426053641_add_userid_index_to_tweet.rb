class AddUseridIndexToTweet < ActiveRecord::Migration
  def change
  	  	add_index :tweets, :user_id
  end
end
