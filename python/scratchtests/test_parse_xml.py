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
from lxml import etree
filepath = 'xml-simple-001.xml'
print "Reading {}\n--\n".format(filepath)
doc = etree.parse(filepath)
print etree.tostring(doc)

lp.section()
print "To get the root Element from the doc etree, we use the getroot() method"
docroot = doc.getroot()
print "docroot is an Element object = {}".format(docroot)
print "The tag of docroot: {}".format(docroot.tag)
print "The prefix of docroot: {}".format(docroot.prefix)
print "The base URI of docroot: {}".format(docroot.base)
print "Attributes of docroot:"
attrib = docroot.attrib
for key in docroot.attrib:
  value = attrib[key]
  print " - {} : {}".format(key, value)
print "The text of docroot: {}".format(docroot.text)
print "The tail of docroot: {}".format(docroot.tail)
print "Line # of docroot: {}".format(docroot.sourceline)
print "children of docroot: {}".format(len(docroot))
for child_element in docroot:
  tag = child_element.tag
  print " - " + tag
print "...as you can see, the children are like members of a list"

lp.section()
print "Namespace Map"
#a namespace map is a python dictionary that relates namespace prefixes to namespaces
# - the keys are namespace prefixes 
# - ...and the values are NSURIs
# - to define the NSURI of the blank namespace, use an entry whose key is None
nsm = {"html": "http://www.w3.org/1999/xhtml"}
print nsm

lp.section()
print "Find:"
for x in ['html:head', "html:body", "html:head/meta", "html:body/p"]:
  print " - {}: {}".format(x,docroot.find(x,namespaces=nsm))
#print "docroot is subclass Comment: {}".format( issubclass(docroot,etree._Comment) )


lp.section()
print "FindAll()"
#I clearly don't have the hang of using findall yet
for x in ['html:head', "html:body", "html:p", "html:a"]:
  print " - {}: {}".format(x,docroot.find(x,namespaces=nsm))

lp.section()
print "getiterator()"
for elt in doc.getiterator():
  print elt.tag

lp.section()
print "XPath for docroot"
for elem in docroot.xpath('//html:p',namespaces=nsm):
  print elem.text

lp.section()
from lxml import etree
filepath = 'xml-show-bgp-summary.txt'
print "Reading {}\n--\n".format(filepath)
bgp = etree.parse(filepath)
print etree.tostring(bgp)

lp.section()
print "XPath: get the AS number for peer with address 9.1.92.129"
bgproot = bgp.getroot()
asnumber  = bgproot.xpath('bgp-information/bgp-peer[peer-address="9.1.92.129"]/peer-as')[0].text
print "AS number should be 9192: {} ({})".format(asnumber, asnumber == "9192")
print "It's important to note that strings don't match integers.  9192 != '9192': {}".format(9192 != "9192")
print "but what about a float and an int?  9192.0 == 9192: {}".format(9192.0 == 9192)

lp.section()
bgp_peers = bgproot.xpath('//bgp-peer')
for peer in bgp_peers[0:2]:
  print peer
  address = peer.xpath('peer-address')[0].text
  asn = peer.xpath('peer-as')[0].text
  state = peer.xpath('peer-state')[0].text
  fail = peer.xpath('peer-death')
  print "An xpath that doesn't match any nodes has a length of: {}".format(len(fail))
  print "Peer {}, AS: {}, State: {}".format(address,asn,state)
  print etree.tostring(peer)
