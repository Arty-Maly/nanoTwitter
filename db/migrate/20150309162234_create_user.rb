class CreateUser < ActiveRecord::Migration


  def self.up 
  	create_table :users do |t|
  		t.string :handle
  		t.string :password_hash
  		t.string :password_salt
  		t.timestamps
  	end
  end

  def self.down
  end
end
