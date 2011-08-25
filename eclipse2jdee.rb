#!/usr/bin/env ruby

# eclipse2jdee -- Simple script to convert eclipse project
# configurations to emacs' jdee project files
#
# Copyright 2011 Bryan Shell. All right reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#    1. Redistributions of source code must retain the above copyright notice,
#       this list of conditions and the following disclaimer.
#
#    2. Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY BRYAN SHELL ``AS IS'' AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
# EVENT SHALL BRYAN SHELL OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
# OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
# EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

require 'optparse'
require 'rexml/document'
require 'erb'
require 'pathname'
include REXML


force_overwrite = false
basedir = Pathname.new(Pathname.new(".").realpath)
project_file_name = "prj.el"

OptionParser.new do |opts|
  opts.banner = "Usage #$0 [options] [classpath-file] [project-file]"
  opts.separator "Creates the JDEE configuration from an existing eclipse project"
  opts.separator ""
  opts.separator "Examples:"
  opts.separator "#$0 -f .classpath .project #Create a new prj.el file from the eclipse project files"
  opts.separator ""
  opts.separator "Specific options:"
  opts.on("-f", "--force", "Overwrite any exisiting configuration") {force_overwrite = true}
  opts.on("-b", "--basedir b", "Root of the project if not the current working dir") {|b| basedir = Pathname.new(Pathname.new(b).realpath)}

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
jde_sourcepath = sourcepath_elements.sort.uniq
jde_global_classpath = classpath_elements.sort.uniq
jde_compile_option_directory = compile_output
jde_build_function = "jde-ant-build"
jde_ant_program = "./build.sh"
jde_ant_enable_find = "t"
jde_ant_read_target = "t"
jde_jdk = "1.6"
jde_db_option_connect_socket = "5005"

project_file = File.join(basedir, project_file_name)
if force_overwrite or !File.exists?(project_file)
  puts "Writing new project file to #{project_file}"
  File.open(project_file, "w") { |f| f.puts(template.result) }
else
  puts "Project file exisits, #{project_file}, doing nothing"
end
