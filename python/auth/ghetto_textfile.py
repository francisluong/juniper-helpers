class Pwdb:

  def __init__ (self):
    self.length = dict()
    self.database = dict()
    from Crypto.Cipher import AES
    from Crypto import Random
    mode = AES.MODE_CBC
    self.bs = 32
    key = Random.new().read(self.bs)
    iv = Random.new().read(16)
    self.c = AES.new(key, mode, iv)
    self.d = AES.new(key, mode, iv)

  def add_user_passwd (self, user, passwd):
    self.length[user] = len(passwd)
    self.database[user] = self.c.encrypt(passwd.ljust(self.bs))

  def passwd (self, user):
    if user in self.database:
      length = self.length[user]
      return self.d.decrypt(self.database[user])[0:length]
    else:
      return ""

  def load (self, filename):
    import yaml
    import sys
    if sys.platform == "linux2":
      import os,stat
      os.chmod(filename,stat.S_IRUSR|stat.S_IWUSR)
    with open(filename) as fh:
      users = yaml.safe_load(fh)
    for user in users:
      self.add_user_passwd(user,users[user])

  def keys(self):
    return self.database.keys()
