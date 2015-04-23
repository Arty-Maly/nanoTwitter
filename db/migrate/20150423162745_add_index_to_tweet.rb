class AddIndexToTweet < ActiveRecord::Migration
  def change
  	add_index :tweets, :created_at
  end
end
