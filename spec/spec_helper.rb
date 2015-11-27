require 'rubygems'
require 'bundler'

if ENV['COVERAGE']
  require 'simplecov'
  require 'simplecov-rcov'

  SimpleCov.formatters = [
    SimpleCov::Formatter::RcovFormatter
  ]

  SimpleCov.start
end
