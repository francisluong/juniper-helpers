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
import yaml
import pprint
doc1 = """
  a: 1
  b: 2
  c: 3
  d: 4
"""
print dir(yaml)
y1 = yaml.safe_load(doc1)
print yaml.dump(y1)

###
lp.section()
f = open("doc2.yml")
y2 = yaml.load_all(f)

print y2

for doc in y2:
  print "--- Document ---"
  for data in doc:
    print "{}: {}".format(repr(data), repr(doc[data]))

f.close()
