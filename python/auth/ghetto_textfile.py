class Pwdb:
  def __init__ (self,filename = "~/.python/ghettopw.db"):
    self.filename = filename
    self.length = dict()
    self.database = dict()
    from Crypto.Cipher import AES
    from Crypto import Random
    mode = AES.MODE_CBC
    self.bs = 16
    key = Random.new().read(self.bs)
    iv = Random.new().read(self.bs)
    self.c = AES.new(key, mode, iv)
    self.d = AES.new(key, mode, iv)
  def add_user_passwd (self, user, passwd):
    self.length[user] = len(passwd)
    fillpass = passwd.ljust(self.bs)
    self.database[user] = self.c.encrypt(fillpass)
  def user_exists (self, user):
    return user in self.database
  def passwd (self, user):
    if user in self.database:
      length = self.length[user]
      fillpass = self.d.decrypt(self.database[user])
      passwd = fillpass[0:length]
      return passwd
    else:
      return ""

def test_pwdb():
  pwdb = Pwdb()
  assert pwdb.filename == "~/.python/ghettopw.db"
  assert pwdb.database == {}
  assert pwdb.passwd("mary") == ""
  user = "bob"
  passwd  = "abc123"
  pwdb.add_user_passwd(user, passwd)
  assert pwdb.database[user] != passwd
  assert pwdb.passwd(user) == passwd
  user = "joe"
  passwd  = "1q2w3e"
  pwdb.add_user_passwd(user, passwd)
  assert pwdb.passwd(user) == passwd

