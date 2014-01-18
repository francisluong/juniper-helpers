import sys, os
sys.path.append(os.path.expanduser("~/juniper-helpers/python"))
del sys, os
from auth.ghetto_textfile import Pwdb

def test_pwdb_empty():
  pwdb = Pwdb()
  assert pwdb.database == {}
  #user mary doesn't exist - should return ""
  assert pwdb.passwd("mary") == ""

def test_pwdb_addusers():
  pwdb = Pwdb()
  passwd = {}
  #add user bob to the database
  user = "bob"
  passwd[user]  = "abc123"
  pwdb.add_user_passwd(user, passwd[user])
  #we save only an encrypted form of the password
  assert pwdb.database[user] != passwd[user]
  #but you can unencrypt it pretty easily
  assert pwdb.passwd(user) == passwd[user]
  user = "joe"
  passwd[user]  = "1q2w3e"
  pwdb.add_user_passwd(user, passwd[user])
  assert pwdb.passwd(user) == passwd[user]

def test_pwdb_load():
  pwdb = Pwdb()
  filename = "test/sample_ghettopw.yaml"
  import os, stat
  #reset mode to 666
  os.chmod(filename,stat.S_IRUSR|stat.S_IWUSR|stat.S_IRGRP|stat.S_IROTH)
  pwdb.load(filename)
  #ensure file is not group/other readable, mode 600
  permissions = oct(os.stat(filename)[stat.ST_MODE])[-3:]
  assert permissions == "600"
  #now we verify users vs. file contents
  import yaml
  with open(filename) as fh:
    passwords = yaml.safe_load(fh)
  #verify passwords per user
  for user in passwords:
    assert pwdb.passwd(user) == passwords[user]
  assert pwdb.keys() == passwords.keys()
  #add a user and make sure length is longer
  pwdb.add_user_passwd("bob","bob")
  assert len(pwdb.keys()) > len(passwords.keys())
  #revert file permissions
  os.chmod(filename,stat.S_IRUSR|stat.S_IWUSR|stat.S_IRGRP|stat.S_IROTH)
