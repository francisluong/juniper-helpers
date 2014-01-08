#!/usr/bin/python

class Lineprinter:
  def __init__ (self):
    self.value = 0
  def incr(self):
    self.value = self.value + 1
  def section(self):
    print "\n\n=== %d ===" % self.value
    self.incr()
lp = Lineprinter()

###
lp.section()
#we use the juniper version of ncclient v0.1a from https://github.com/Juniper/ncclient
from ncclient import manager
from pprint import pprint as pp

#for argv
import sys, os

def connect(host, username, port=830, password=None, timeout=10, hostkey_verify=False):
  """
    Return a netconf connection object
     - prompt for password if None
  """
  if password is None: 
    from getpass import getpass
    password = getpass('{}@{} password: '.format(user, host))
  #return jnpr.junos.Device(host, user=user, password=password).open()
  return manager.connect(host=host, port=port, username=username, password=password,
    timeout=timeout, hostkey_verify=hostkey_verify)

if __name__ == '__main__':
  if len(sys.argv) == 1:
    print "usage: {} <host> [ <username> ]".format(sys.argv[0])
  else:
    if len(sys.argv) == 2:
      user = os.getenv("USER")
    else:
      user = sys.argv[2]
    host = sys.argv[1]
    sess = connect(host, user)
    print "Attributes of ncclient Session:"
    pp(dir(sess))

    lp.section()
    result = sess.get_chassis_inventory()
    print "Attrubites of {}".format(result)
    pp(dir(result))

    #lp.section()
    #from lxml import etree
    #root = etree.parse(result.data_xml)
    #print etree.tostring(root, pretty_print=True)

    lp.section()
    print result.data_xml

    lp.section()
    print "Chassis:", result.xpath('//chassis/description')[0].text
    if result.xpath('//chassis/description')[0].text == "JUNOSV-FIREFLY":
      firefly = True
    else: 
      firefly = False
    print "Chassis Serial-Number:", result.xpath('//chassis/serial-number')[0].text
    cb_serial = result.xpath('//chassis/chassis-module[name="CB 0"]/serial-number')
    if len(cb_serial) == 0:
      serial = "''"
    else:
      serial = cb_serial[0].text
    print "CB0 Serial Number:", serial

    lp.section()
    from itertools import izip
    if not firefly:
      names = result.xpath('//chassis/chassis-module/name')
      serials = result.xpath('//chassis/chassis-module/serial-number')
      parts = result.xpath('//chassis/chassis-module/model-number')
      print "Chassis Modules: (there are {} of them)".format( len(names) )
      for name, serial, part in izip(names, serials, parts):
        print " - {0}: {1} // {2}".format( name.text, part.text, serial.text )  
    else:
      names = result.xpath('//chassis/chassis-module/name')
      print "Chassis Modules: (there are {} of them)".format( len(names) )
      for name in names:
        print " - ", name.text


