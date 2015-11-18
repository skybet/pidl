require 'simplecov'
require 'simplecov-rcov'

SimpleCov.formatters = [
    SimpleCov::Formatter::RcovFormatter
]

SimpleCov.start
