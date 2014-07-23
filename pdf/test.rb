#!/usr/bin/env ruby
# coding: utf-8

# A simple app to count the number of pages in a PDF File.

require 'rubygems'
require 'pry'
require 'pdf/reader'

filename = 'demo_1.pdf'
#filename = '1.pdf'
file = PDF::Reader.new(filename)
page = file.pages[18]
r    = page.text_receiver
binding.pry