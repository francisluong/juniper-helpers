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
import pprint
pp = pprint.PrettyPrinter(indent=4)
print "We will be working with lxml.etree"
pp.pprint(dir(etree))


###
lp.section()
root = etree.Element('html')
tree = etree.ElementTree(root)
print "This is what an Element object can do:"
pp.pprint(dir(root))

lp.section()
print "Now we build an xml tree..."
print "add a <head> subelement"
root.append( etree.Element("head") )
print "add a <body> subelement"
body = etree.Element("body")
root.append( body )
print "add <h1> as a sub of <body> and set the text to 'Hello World!'"
h1 = etree.Element("h1") 
h1.text = "Hello World!"
body.append( h1 )
print "add a comment before the <h1>"
body_comment = etree.Comment("This is a body comment")
h1.addprevious( body_comment )

lp.section()
print "This is the pretty_print output for our xml tree"
print etree.tostring(tree, pretty_print=True)
#help(root)
