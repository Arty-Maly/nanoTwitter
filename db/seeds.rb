user_list = [['illisio@narod.ru', 'Arty-Maly', '123', 'asd'],['Yuya@brandeis.edu','Choo', '123', 'asd'], ['example@me.com','Marty', '123', 'asd']]

user_list.each do  |handle, password_hash, salt|
	User.create(handle: handle, password_hash: password_hash, password_salt: salt)
end