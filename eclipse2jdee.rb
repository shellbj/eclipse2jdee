#!/usr/bin/env ruby
require 'optparse'
require 'rexml/document'
require 'erb'
require 'pathname'
include REXML


force_overwrite = false
basedir = Pathname.new(File.dirname(Pathname.new(".").realpath))

OptionParser.new do |opts|
  opts.banner = "Usage #$0 [options] [classpath-file] [project-file]"
  opts.separator "Creates the JDEE configuration from an existing eclipse project"
  opts.separator ""
  opts.separator "Examples:"
  opts.separator "#$0 -f .classpath .project #Create a new prj.el file from the eclipse project files"
  opts.separator ""
  opts.separator "Specific options:"
  opts.on("-f", "--force", "Overwrite any exisiting configuration") {force_overwrite = true}
  opts.on("-b", "--basedir b", "Root of the project if not the current working dir") {|b| basedir = Pathname.new(File.dirname(Pathname.new(b).realpath))}

  opts.on("-h", "--help", "Prints this message") { puts opts; exit }
end.parse!

classpath = ARGV[0]

if classpath.nil?
  puts "Classpath file required"
  exit 1
end

def get_attribute_value_from_elements(doc, xpath, key, basedir)
  elements = []
  doc.elements.each(xpath) do |xml|
    if !xml.attributes[key].nil?
      path = Pathname.new(Pathname.new(xml.attributes[key]).realpath)
      elements << File.join(".", path.relative_path_from(basedir))
    end
  end
  elements
end

classpath_doc = Document.new(File.new(classpath))

classpath_elements = get_attribute_value_from_elements(classpath_doc, '/classpath/classpathentry[@kind="lib"]', "path", basedir)

sourcepath_elements = get_attribute_value_from_elements(classpath_doc, '/classpath/classpathentry[@kind="src"]', "path", basedir)

get_attribute_value_from_elements(classpath_doc, '/classpath/classpathentry[@kind="lib"]', "sourcepath", basedir).each { |e| sourcepath_elements << e }

compile_output = get_attribute_value_from_elements(classpath_doc, '/classpath/classpathentry[@kind="output"]', "path", basedir)

compile_output.each { |e| classpath_elements << e }

project_name = nil

project = ARGV[1]
project_doc = nil
if !project.nil?
  project_doc = Document.new(File.new(project))

  project_name = []
  project_doc.elements.each('/projectDescription/name') {|xml| project_name << xml.text}
end

template_dir = File.dirname(Pathname.new($0).realpath)
filename = "jdee_prj.template"
template = ERB.new(IO.read(File.join(template_dir, filename)), 0, "%<>")

jde_project_name = project_name
jde_sourcepath = sourcepath_elements
jde_global_classpath = classpath_elements
jde_compile_option_directory = compile_output
jde_build_function = "jde-ant-build"
jde_ant_program = "./build.sh"
jde_ant_enable_find = "t"
jde_ant_read_target = "t"
jde_jdk = "1.6"
jde_db_option_connect_socket = "5005"

puts template.result

