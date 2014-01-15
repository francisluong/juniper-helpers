#!/usr/bin/python

import paramiko, os
ssh = paramiko.SSHClient()
keypath = os.path.expanduser('~/.ssh/known_hosts')
ssh.load_host_keys(keypath)
ssh.connect( '192.168.1.31', username = 'lab', password = 'lab123' )
stdin, stdout, stderr = ssh.exec_command( 'show version' )
for line in stdout:
  print '... ' + line.strip('\n')
ssh.close()
