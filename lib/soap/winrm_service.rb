#############################################################################
# Copyright © 2010 Dan Wanek <dan.wanek@gmail.com>
#
#
# This file is part of WinRM.
# 
# WinRM is free software: you can redistribute it and/or
# modify it under the terms of the GNU General Public License as published
# by the Free Software Foundation, either version 3 of the License, or (at
# your option) any later version.
# 
# WinRM is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
# Public License for more details.
# 
# You should have received a copy of the GNU General Public License along
# with WinRM.  If not, see <http://www.gnu.org/licenses/>.
#############################################################################
Handsoap.http_driver = :http_client

module WinRM
  module SOAP
    class WinRMWebService < Handsoap::Service
      include SOAP

      @@raw_soap = false

      def initialize()
        if $DEBUG
          @debug = File.new('winrm_debug.out', 'w')
          @debug.sync = true
        end
      end

      def self.set_auth(user,pass)
        @@user = user
        @@pass = pass
      end

      # Turn off parsing and just return the soap response
      def self.raw_soap!
        @@raw_soap = true
      end


      # ********* Begin Hooks *********

      def on_create_document(doc)
        doc.alias NS_ADDRESSING, 'http://schemas.xmlsoap.org/ws/2004/08/addressing'
        doc.alias NS_ENUM,       'http://schemas.xmlsoap.org/ws/2004/09/enumeration'
        doc.alias NS_WSMAN_DMTF, 'http://schemas.dmtf.org/wbem/wsman/1/wsman.xsd'
        doc.alias NS_WSMAN_MSFT, 'http://schemas.microsoft.com/wbem/wsman/1/wsman.xsd'
        doc.alias NS_SCHEMA_INST,'http://www.w3.org/2001/XMLSchema-instance'
        doc.alias NS_WIN_SHELL,  'http://schemas.microsoft.com/wbem/wsman/1/windows/shell'
        doc.alias NS_CIMBINDING, 'http://schemas.dmtf.org/wbem/wsman/1/cimbinding.xsd'

        header = doc.find('Header')
        header.add("#{NS_ADDRESSING}:To", WinRMWebService.uri)
        header.add("#{NS_ADDRESSING}:ReplyTo") {|rto|
          rto.add("#{NS_ADDRESSING}:Address",'http://schemas.xmlsoap.org/ws/2004/08/addressing/role/anonymous') {|addr|
            addr.set_attr('mustUnderstand','true')
          }
        }
        header.add("#{NS_WSMAN_DMTF}:MaxEnvelopeSize",'153600') {|mes|
          mes.set_attr('mustUnderstand','true')
        }
        header.add("#{NS_ADDRESSING}:MessageID", "uuid:#{UUID.generate.upcase}")
        header.add("#{NS_WSMAN_DMTF}:Locale") {|loc|
          loc.set_attr('xml:lang','en-US')
          loc.set_attr('mustUnderstand','false')
        }
        header.add("#{NS_WSMAN_MSFT}:DataLocale") {|loc|
          loc.set_attr('xml:lang','en-US')
          loc.set_attr('mustUnderstand','false')
        }
        header.add("#{NS_WSMAN_DMTF}:OperationTimeout",'PT60.000S')
      end

      # Adds knowledge of namespaces to the response object.  These have to be identical to the 
      # URIs returned in the XML response.  For example, I had some issues with the 'soap'
      # namespace because my original URI did not end in a '/'
      # @example
      #   Won't work: http://schemas.xmlsoap.org/soap/envelope
      #   Works: http://schemas.xmlsoap.org/soap/envelope/
      def on_response_document(doc)
        doc.add_namespace NS_ADDRESSING, 'http://schemas.xmlsoap.org/ws/2004/08/addressing'
        doc.add_namespace NS_ENUM,       'http://schemas.xmlsoap.org/ws/2004/09/enumeration'
        doc.add_namespace NS_TRANSFER,   'http://schemas.xmlsoap.org/ws/2004/09/transfer'
        doc.add_namespace NS_WSMAN_DMTF, 'http://schemas.dmtf.org/wbem/wsman/1/wsman.xsd'
        doc.add_namespace NS_WSMAN_MSFT, 'http://schemas.microsoft.com/wbem/wsman/1/wsman.xsd'
        doc.add_namespace NS_WIN_SHELL,  'http://schemas.microsoft.com/wbem/wsman/1/windows/shell'
        doc.add_namespace NS_CIMBINDING, 'http://schemas.dmtf.org/wbem/wsman/1/cimbinding.xsd'
      end

      def on_after_create_http_request(req)
        req.set_auth @@user, @@pass
        req.set_header('Content-Type','application/soap+xml;charset=UTF-8')
        puts "SOAP DOCUMENT=\n#{req.body}"
      end

      def on_http_error(resp)
        puts "HTTP ERROR: #{resp.status}"
        puts "HEADERS=\n#{resp.headers}"
        puts "BODY=\n#{resp.body}"
      end


      # ********** End Hooks **********


      # Create a Shell on the destination host
      # @param [String<optional>] i_stream Which input stream to open.  Leave this alone unless you know what you're doing
      # @param [String<optional>] o_stream Which output stream to open.  Leave this alone unless you know what you're doing
      # @return [String] The ShellId from the SOAP response.  This is our open shell instance on the remote machine.
      def open_shell(i_stream = 'stdin', o_stream = 'stdout stderr')
        header = {
          "#{NS_WSMAN_DMTF}:ResourceURI" => {'mustUnderstand' => 'true', :text => 'http://schemas.microsoft.com/wbem/wsman/1/windows/shell/cmd'},
          "#{NS_ADDRESSING}:Action" => {'mustUnderstand' => 'true', :text => 'http://schemas.xmlsoap.org/ws/2004/09/transfer/Create'},
          "#{NS_WSMAN_DMTF}:OptionSet" => [
            {"#{NS_WSMAN_DMTF}:Option" => {:name => 'WINRS_NOPROFILE', :text =>"FALSE"}},
            {"#{NS_WSMAN_DMTF}:Option" => {:name => 'WINRS_CODEPAGE', :text =>"437"}}
          ]
        }

        resp = invoke("#{NS_WIN_SHELL}:Shell", {:soap_action => :auto, :http_options => nil, :soap_header => header}) do |shell|
          shell.add("#{NS_WIN_SHELL}:InputStreams", i_stream)
          shell.add("#{NS_WIN_SHELL}:OutputStreams",o_stream)
        end

        # Get the Shell ID from the response
        (resp/"//*[@Name='ShellId']").to_s
      end

      # Run a command on a machine with an open shell
      # @param [String] shell_id The shell id on the remote machine.  See #open_shell
      # @param [String] command The command to run on the remote machine
      # @return [String] The CommandId from the SOAP response.  This is the ID we need to query in order to get output.
      def run_command(shell_id, command)
        header = {
          "#{NS_WSMAN_DMTF}:ResourceURI" => {'mustUnderstand' => 'true', :text => 'http://schemas.microsoft.com/wbem/wsman/1/windows/shell/cmd'},
          "#{NS_ADDRESSING}:Action" =>
            {'mustUnderstand' => 'true', :text => 'http://schemas.microsoft.com/wbem/wsman/1/windows/shell/Command'},
          "#{NS_WSMAN_DMTF}:SelectorSet" =>
            {"#{NS_WSMAN_DMTF}:Selector" => {:name => 'ShellId', :text => shell_id}},
          "#{NS_WSMAN_DMTF}:OptionSet" => {
            "#{NS_WSMAN_DMTF}:Option" => {:name => 'WINRS_CONSOLEMODE_STDIN', :text =>"TRUE"},
          }
        }
        # Issue the Command
        resp = invoke("#{NS_WIN_SHELL}:CommandLine", {:soap_action => :auto, :http_options => nil, :soap_header => header}) do |cli|
          cli.add("#{NS_WIN_SHELL}:Command","\"#{command}\"")
        end

        (resp/"//#{NS_WIN_SHELL}:CommandId").to_s
      end

      # Get the Output of the given shell and command
      # @param [String] shell_id The shell id on the remote machine.  See #open_shell
      # @param [String] command_id The command id on the remote machine.  See #run_command
      # @return [Hash] :stdout and :stderr
      def get_command_output(shell_id, command_id)
        header = {
          "#{NS_WSMAN_DMTF}:ResourceURI" => {'mustUnderstand' => 'true', :text => 'http://schemas.microsoft.com/wbem/wsman/1/windows/shell/cmd'},
          "#{NS_ADDRESSING}:Action" =>
            {'mustUnderstand' => 'true', :text => 'http://schemas.microsoft.com/wbem/wsman/1/windows/shell/Receive'},
          "#{NS_WSMAN_DMTF}:SelectorSet" =>
            {"#{NS_WSMAN_DMTF}:Selector" => {:name => 'ShellId', :text => shell_id}}
        }
        # Get Command Output
        resp = invoke("#{NS_WIN_SHELL}:Receive", {:soap_action => :auto, :http_options => nil, :soap_header => header}) do |rec|
          rec.add("#{NS_WIN_SHELL}:DesiredStream",'stdout stderr') do |ds|
            ds.set_attr('CommandId', command_id)
          end
        end

        cmd_stdout = ''
        cmd_stderr = ''
        (resp/"//*[@Name='stdout']").each do |n|
          next if n.to_s.nil?
          cmd_stdout << Base64.decode64(n.to_s)
        end
        (resp/"//*[@Name='stderr']").each do |n|
          next if n.to_s.nil?
          cmd_stderr << Base64.decode64(n.to_s)
        end
        {:stdout => cmd_stdout, :stderr => cmd_stderr}
      end

      # Clean-up after a command.
      # @see #run_command
      # @param [String] shell_id The shell id on the remote machine.  See #open_shell
      # @param [String] command_id The command id on the remote machine.  See #run_command
      # @return [true] This should have more error checking but it just returns true for now.
      def cleanup_command(shell_id, command_id)
        header = {
          "#{NS_WSMAN_DMTF}:ResourceURI" => {'mustUnderstand' => 'true', :text => 'http://schemas.microsoft.com/wbem/wsman/1/windows/shell/cmd'},
          "#{NS_ADDRESSING}:Action" =>
          {'mustUnderstand' => 'true', :text => 'http://schemas.microsoft.com/wbem/wsman/1/windows/shell/Signal'},
            "#{NS_WSMAN_DMTF}:SelectorSet" =>
          {"#{NS_WSMAN_DMTF}:Selector" => {:name => 'ShellId', :text => shell_id}}
        }
        # Signal the Command references to terminate (close stdout/stderr)
        resp = invoke("#{NS_WIN_SHELL}:Signal", {:soap_action => :auto, :http_options => nil, :soap_header => header}) do |sig|
          sig.set_attr('CommandId', command_id)
          sig.add("#{NS_WIN_SHELL}:Code",'http://schemas.microsoft.com/wbem/wsman/1/windows/shell/signal/terminate')
        end
        true
      end

      # Close the shell
      # @param [String] shell_id The shell id on the remote machine.  See #open_shell
      # @return [true] This should have more error checking but it just returns true for now.
      def close_shell(shell_id)
        header = {
          "#{NS_WSMAN_DMTF}:ResourceURI" => {'mustUnderstand' => 'true', :text => 'http://schemas.microsoft.com/wbem/wsman/1/windows/shell/cmd'},
          "#{NS_ADDRESSING}:Action" =>
          {'mustUnderstand' => 'true', :text => 'http://schemas.xmlsoap.org/ws/2004/09/transfer/Delete'},
            "#{NS_WSMAN_DMTF}:SelectorSet" =>
          {"#{NS_WSMAN_DMTF}:Selector" => {:name => 'ShellId', :text => shell_id}}
        }
        # Delete the Shell reference
        resp = invoke(:nil_body, {:soap_action => nil, :soap_body => true, :http_options => nil, :soap_header => header})
        true
      end

      # Run a Powershell script that resides on the local box.
      # @param [String] script_file The string representing the path to a Powershell script
      # @return [Hash] :stdout and :stderr
      def run_powershell_script(script_file)
        script = File.read(script_file)
        script = script.chars.to_a.join("\x00").chomp.encode('ASCII-8BIT')
        script = Base64.strict_encode64(script)

        shell_id = open_shell
        command_id =  run_command(shell_id, "powershell -encodedCommand #{script}")
        command_output = get_command_output(shell_id, command_id)
        cleanup_command(shell_id, command_id)
        close_shell(shell_id)
        command_output
      end


      def run_enumeration
        header = {
          "#{NS_WSMAN_DMTF}:ResourceURI" => {'mustUnderstand' => 'true', :text => 'http://schemas.microsoft.com/wbem/wsman/1/wmi/root/cimv2/*'},
          "#{NS_ADDRESSING}:Action" =>
          {'mustUnderstand' => 'true', :text => 'http://schemas.xmlsoap.org/ws/2004/09/enumeration/Enumerate'}
        }
        
        resp = invoke("#{NS_ENUM}:Enumerate", {:soap_action => :auto, :http_options => nil, :soap_header => header}) do |enum|
          enum.add("#{NS_WSMAN_DMTF}:OptimizeEnumeration")
          enum.add("#{NS_WSMAN_DMTF}:MaxElements",'32000')
          mattr = nil
          enum.add("#{NS_WSMAN_DMTF}:Filter",'select Name,Status from Win32_Service') do |filt|
            filt.set_attr('Dialect','http://schemas.microsoft.com/wbem/wsman/1/WQL')
          end
        end
      end

      # Add a hierarchy of elements from hash data
      # @example Hash to XML
      #   {:this => {:text =>'that'},'top' => {:id => '32fss', :text => 'TestText', {'middle' => 'bottom'}}}
      #   becomes...
      #   <this>that</this>
      #   <top Id='32fss'>
      #     TestText
      #     <middle>bottom</middle>
      #   </top>
      def add_hierarchy!(node, e_hash, prefix = NS_ADDRESSING)
        prefix << ":" unless prefix.nil?
        e_hash.each_pair do |k,v|
          name = (k.is_a?(Symbol) && k != :text) ? k.to_s.camel_case : k
          if v.is_a? Hash
            node.add("#{prefix}#{name}", v[:text]) do |n|
              add_hierarchy!(n, v, prefix)
            end
          elsif v.is_a? Array
            node.add("#{prefix}#{name}") do |n|
              v.each do |i|
                add_hierarchy!(n, i, prefix)
              end
            end
          else
            node.set_attr(name, v) unless k == :text
          end
        end
      end


      # To create an empty body set :soap_body => true in the invoke options and set the action to :nil_body
      def iterate_hash_array(element, hash_array)
        add_hierarchy!(element, hash_array, nil) unless hash_array.key?(:nil_body)
      end


      # Private Methods (Builders and Parsers)
      private

      def build!(node, opts = {}, &block)
        #EwsBuilder.new(node, opts, &block)
      end

      def parse!(response, opts = {})
        return response if @@raw_soap
        #EwsParser.new(response).parse(opts)
      end

    end # class WinRMWebService
  end # module SOAP
end # WinRM
