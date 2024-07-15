#!/usr/bin/env puma

_load_from File.expand_path("../defaults.rb", __FILE__)

environment "production"

threads 0, 5
workers 8
